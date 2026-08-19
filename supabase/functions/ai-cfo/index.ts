// AI CFO — 사용자 재무 데이터를 분석해 오늘자 리포트를 생성/갱신한다.
// OPENAI_API_KEY 가 설정돼 있으면 요약문을 LLM 으로 생성하고,
// 없으면 규칙 기반(휴리스틱)으로 동일한 구조의 리포트를 만든다.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function won(n: number): string {
  const a = Math.abs(n);
  if (a >= 1e8) return `${(n / 1e8).toFixed(1)}억`;
  if (a >= 1e4) return `${Math.round(n / 1e4)}만`;
  return `${Math.round(n)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    // 사용자 토큰으로 클라이언트 생성 → RLS 로 본인 데이터만 조회.
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData } = await sb.auth.getUser();
    const user = userData.user;
    if (!user) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // ── 데이터 수집 ──────────────────────────────────────────
    const [profile, snaps, airbnb, shorts, dividends, land, goals, allocations] =
      await Promise.all([
        sb.from("profiles").select("*").eq("id", user.id).maybeSingle(),
        sb.from("financial_snapshots").select("*").order("as_of"),
        sb.from("airbnb_units").select("*").order("sort_order"),
        sb.from("shorts_channels").select("*"),
        sb.from("dividend_holdings").select("*"),
        sb.from("land_projects").select("*"),
        sb.from("goals").select("*").order("sort_order"),
        sb.from("allocations").select("*"),
      ]);

    const snapRows = snaps.data ?? [];
    const latest = snapRows.at(-1);
    const prev = snapRows.at(-2);
    const freedomTarget = Number(profile.data?.freedom_target ?? 10_000_000);
    const cashflow = Number(latest?.non_salary_cashflow ?? 0);
    const prevCashflow = Number(prev?.non_salary_cashflow ?? cashflow);
    const mom = prevCashflow > 0
      ? ((cashflow - prevCashflow) / prevCashflow) * 100
      : 0;
    // Freedom Score = 현금흐름 / 월 목표 현금흐름 × 100.
    const freedom = freedomTarget > 0 ? (cashflow / freedomTarget) * 100 : 0;

    // 월 목표 현금흐름까지 남은 개월(현재 MoM 성장률 가정).
    const target = freedomTarget;
    let etaMonths = 24;
    if (cashflow >= target) etaMonths = 0;
    else if (mom > 0.5) {
      etaMonths = Math.ceil(
        Math.log(target / cashflow) / Math.log(1 + mom / 100),
      );
    }
    const eta = new Date();
    eta.setMonth(eta.getMonth() + Math.min(etaMonths, 120));
    const etaStr = eta.toISOString().slice(0, 10);

    // 준비중 에비 중 남은 준비금이 가장 적은 것.
    const preparing = (airbnb.data ?? []).filter((a) =>
      a.status === "preparing"
    );
    preparing.sort((a, b) =>
      (Number(a.target_fund) - Number(a.reserve_fund)) -
      (Number(b.target_fund) - Number(b.reserve_fund))
    );
    const nextUnit = preparing[0];
    const airbnbReco = nextUnit
      ? `${nextUnit.name} 준비금 우선 충당 (잔여 ${
        won(Number(nextUnit.target_fund) - Number(nextUnit.reserve_fund))
      }원)`
      : "신규 에비 후보지 발굴 단계";

    // 에비 오픈 예상 시점: 준비금 잔여 ÷ 사업자금 월 배분액.
    const allocRows = allocations.data ?? [];
    const businessMonthly = allocRows
      .filter((a) => a.pool === "business")
      .reduce((s, a) => s + Number(a.monthly_amount), 0);
    let airbnbOpenEta = "준비 중인 에비 없음";
    if (nextUnit && businessMonthly > 0) {
      const remain = Number(nextUnit.target_fund) - Number(nextUnit.reserve_fund);
      const months = Math.max(0, Math.ceil(remain / businessMonthly));
      const d = new Date();
      d.setMonth(d.getMonth() + months);
      airbnbOpenEta = `${nextUnit.name} — 약 ${months}개월 뒤(${
        d.toISOString().slice(0, 7)
      }), 월 ${won(businessMonthly)}원 적립 기준`;
    } else if (nextUnit) {
      airbnbOpenEta = `${nextUnit.name} 준비 중 — 사업자금 배분을 설정하면 오픈 시점 계산`;
    }

    // 토지 신규 진입 여부: 준비중 에비가 있으면 유동성 이유로 보류.
    const landOk = preparing.length === 0;
    const landReason = landOk
      ? "에비 준비 완료 — 토지 신규 진입 검토 가능"
      : "에비 준비금 우선 — 유동성 잠기는 토지는 당분간 보류";

    const shortsProfit = (shorts.data ?? []).reduce(
      (s, c) => s + Number(c.net_profit),
      0,
    );

    // 숏폼 수익 배분 전략 (전략 문서 규칙).
    let shortsAllocation: string;
    const wan = shortsProfit / 10000; // 만원
    if (wan < 50) {
      shortsAllocation = "월 50만 미만 — 콘텐츠 재투자 100%";
    } else if (wan < 150) {
      shortsAllocation =
        "월 50~150만 — 에어비앤비 40% · 콘텐츠 40% · ETF 10% · 현금 10%";
    } else {
      shortsAllocation =
        "월 150만 이상 — 에어비앤비 35% · 콘텐츠 20% · ETF 25% · 토지 10% · 현금 10%";
    }

    // 지금 가장 먼저 투자할 곳: 에비2 준비 미완이면 준비금 우선.
    const nextPriority = nextUnit
      ? `${nextUnit.name} 준비금 (에비 오픈이 현금흐름을 가장 크게 늘림)`
      : freedom < 100
      ? "배당 성장주 매수로 안정 현금흐름 확대"
      : "토지 프로젝트로 목돈 사이클 시작";

    const monthsToGoal = Math.min(etaMonths, 120);
    const payload = {
      current_pace: `월 현금흐름 ${
        mom >= 0 ? "+" : ""
      }${mom.toFixed(1)}% MoM · 자유지수 ${freedom.toFixed(0)}%`,
      goal_eta: etaStr,
      goal_eta_reason: `현재 월 ${won(cashflow)}원, 목표 ${
        won(freedomTarget)
      }원. 현 성장 속도 유지 시 약 ${monthsToGoal}개월 뒤 달성.`,
      next_priority: nextPriority,
      airbnb_reco: airbnbReco,
      airbnb_open_eta: airbnbOpenEta,
      land_ok: landOk,
      land_reason: landReason,
      land_principle: "원금은 토지에 재투자, 수익금만 에비·ETF 현금흐름 자산으로 이동",
      etf_rebalance: freedom < 100
        ? "배당 성장주(SCHD) 비중 상향으로 현금흐름 가속"
        : "현 비중 유지, 성장/배당 균형",
      shorts_reinvest: shortsAllocation,
    };

    // ── 요약문 생성 (LLM 우선, 없으면 규칙 기반) ───────────────
    let summary =
      `자유 지수 ${freedom.toFixed(0)}% · 현재 속도라면 ${etaMonths}개월 내 ` +
      `월 1,000만 현금흐름 달성 예상`;

    const openaiKey = Deno.env.get("OPENAI_API_KEY");
    if (openaiKey) {
      try {
        const res = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openaiKey}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            temperature: 0.6,
            messages: [
              {
                role: "system",
                content:
                  "너는 개인 CFO다. 아래 재무 지표를 근거로 한국어 한 문장(80자 이내)의 핵심 코멘트를 작성한다. 과장 없이 실행 지향적으로.",
              },
              {
                role: "user",
                content: JSON.stringify({
                  freedom_score: freedom,
                  monthly_cashflow: cashflow,
                  mom_growth_pct: mom,
                  goal_eta_months: etaMonths,
                  goals: (goals.data ?? []).map((g) => g.title),
                }),
              },
            ],
          }),
        });
        const j = await res.json();
        const text = j?.choices?.[0]?.message?.content?.trim();
        if (text) summary = text;
      } catch (_) {
        // LLM 실패 시 규칙 기반 요약 유지.
      }
    }

    const today = new Date().toISOString().slice(0, 10);
    const { error } = await sb.from("ai_reports").upsert({
      user_id: user.id,
      report_date: today,
      summary,
      payload,
    }, { onConflict: "user_id,report_date" });

    if (error) throw error;

    return new Response(
      JSON.stringify({ ok: true, summary, payload }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
