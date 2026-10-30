// 경매 물건 종합분석 — property_id 를 받아 해당 물건·자료실·메모를
// 수집한 뒤 LLM 으로 evidence 기반 분석을 수행한다.
// 서버 측 OPENAI_API_KEY 사용 — 클라이언트에 키를 노출하지 않는다.
// RLS 로 본인 데이터만 조회한다.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Evidence 카테고리. 공개 조회 안 된 것은 unknown 유지.
const EVIDENCE_KEYS = [
  "identity",   // 물건 기본 특정 (소재지·면적·층수)
  "condition",  // 건물 상태 (위반건축물·노후도·수리 범위)
  "rights",     // 권리분석 (등기부·임차인·대항력·배당)
  "zone",       // 구역 정보 (모아타운·신통기획·정비구역 지정 여부)
  "eligibility", // 입찰 자격·조합원 자격·지분 요건
  "market",     // 시세·전세가·실거래·매물 동향
  "tax",        // 취득세·양도세·종부세 시나리오
  "funding",    // 자금 계획 (대출 가능액·필요현금·이자)
] as const;

type EvidenceStatus = "unknown" | "pass" | "fail";

interface EvidenceItem {
  status: EvidenceStatus;
  kind?: string;
  source?: string;
  checked_on?: string;
  detail?: string;
}

function unknownEvidence(): Record<string, EvidenceItem> {
  const ev: Record<string, EvidenceItem> = {};
  for (const k of EVIDENCE_KEYS) ev[k] = { status: "unknown" };
  return ev;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
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

    const body = await req.json();
    const propertyId: string | undefined = body?.property_id;
    if (!propertyId) {
      return new Response(
        JSON.stringify({ error: "property_id is required" }),
        { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    // ── 데이터 수집 (RLS 적용) ──────────────────────────────────
    const [propRes, knowledgeRes, calcsRes] = await Promise.all([
      sb.from("auction_properties")
        .select("*")
        .eq("id", propertyId)
        .maybeSingle(),
      // 경매·모아·신속·재개발 관련 자료를 가져온다.
      sb.from("knowledge_notes")
        .select("id, title, body, tags, source, author, source_date, files")
        .overlaps("tags", ["경매", "모아타운", "신속통합", "재개발", "권리분석", "세금", "대출", "입찰"])
        .order("source_date", { ascending: false })
        .limit(30),
      // 해당 물건의 calc_records (inputs._kind=investment).
      sb.from("calc_records")
        .select("id, label, inputs, updated_at")
        .order("updated_at", { ascending: false })
        .limit(20),
    ]);

    const prop = propRes.data;
    if (!prop) {
      return new Response(
        JSON.stringify({ error: "property not found" }),
        { status: 404, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    // calc_records 중 해당 물건에 연결된 것만 필터.
    const calcRows = (calcsRes.data ?? []).filter((r: Record<string, unknown>) => {
      const inp = r.inputs as Record<string, unknown> | null;
      return inp?.property_id === propertyId ||
             inp?._kind === "investment";
    });

    // 자료실 본문은 길 수 있으므로 앞 500 자만 전달.
    const knowledgeSummaries = (knowledgeRes.data ?? []).map(
      (k: Record<string, unknown>) => ({
        title: k.title,
        tags: k.tags,
        source: k.source,
        body: typeof k.body === "string"
          ? (k.body as string).slice(0, 500)
          : null,
      }),
    );

    // 기존 분석 결과가 body 에 포함돼 있으면 참고한다.
    const priorAnalysis = body?.analysis ?? null;

    // ── evidence 초기화 ─────────────────────────────────────────
    // 물건 데이터에서 확인 가능한 것만 채우고, 나머지는 unknown.
    const evidence = unknownEvidence();

    // identity: 물건에 주소·면적이 있으면 pass.
    if (prop.address && prop.title) {
      evidence.identity = {
        status: "pass",
        kind: "물건 기본정보",
        source: "auction_properties",
        checked_on: prop.updated_at,
        detail: `${prop.title} / ${prop.address}`,
      };
    }

    // condition: 위반건축물 체크가 명시적으로 있을 때만.
    const checks = (prop.checks ?? {}) as Record<string, unknown>;
    if (checks.violation === true) {
      evidence.condition = {
        status: "fail",
        kind: "위반건축물",
        source: "auction_properties.checks",
        checked_on: prop.updated_at,
        detail: "위반건축물 감지됨",
      };
    } else if (checks.violation === false) {
      evidence.condition = {
        status: "pass",
        kind: "위반건축물 확인",
        source: "auction_properties.checks",
        checked_on: prop.updated_at,
        detail: "위반건축물 없음 확인",
      };
    }
    // violation 키 자체가 없으면 unknown 유지.

    // zone: district_type 이 설정돼 있으면 기록.
    if (prop.district_type && prop.district_type !== "없음") {
      evidence.zone = {
        status: "pass",
        kind: prop.district_type,
        source: "auction_properties.district_type",
        checked_on: prop.updated_at,
        detail: `${prop.district_type} 구역`,
      };
    }

    // market: current_price 또는 jeonse_price 가 입력돼 있으면.
    if (Number(prop.current_price) > 0 || Number(prop.jeonse_price) > 0) {
      evidence.market = {
        status: "pass",
        kind: "시세 입력",
        source: "auction_properties",
        checked_on: prop.updated_at,
        detail: `시세 ${prop.current_price}, 전세 ${prop.jeonse_price}`,
      };
    }

    // funding: loan_amount 가 있으면 대출 계획 확인.
    // 대출 승인 전이므로 unknown → 금액이 입력돼 있어도 "미확인" 이 맞지만,
    // 계획 자체가 있다는 것은 기록한다.
    if (Number(prop.loan_amount) > 0) {
      evidence.funding = {
        status: "unknown",
        kind: "대출 계획 입력",
        source: "auction_properties",
        checked_on: prop.updated_at,
        detail: `대출 계획 ${prop.loan_amount} — 승인 전 미확정`,
      };
    }

    // ── LLM 분석 (선택) ─────────────────────────────────────────
    const openaiKey = Deno.env.get("OPENAI_API_KEY");

    let llmInsight: string | null = null;
    let llmEvidence: Record<string, EvidenceItem> | null = null;

    if (openaiKey) {
      try {
        const systemPrompt = `너는 한국 부동산 경매 투자 분석가다.
사용자의 물건 데이터, 자료실(강의/전략), 계산 이력을 바탕으로 종합 의견을 제시한다.

규칙:
1. 원문(DB 레코드, 자료실 본문, 등기부 등)에서 직접 확인된 사실만 pass/fail 로 판단한다.
2. 원문 없이 LLM 추론뿐인 항목은 반드시 status:"unknown" 으로 남긴다.
3. 대출은 승인 전까지 금액을 0 으로 간주한다.
4. 감정가를 매도가로 쓰지 않는다. 근거 있는 매도가가 없으면 수익 계산 대신 "매도가 입력 필요"라고 안내한다.
5. 세금은 일반과표/추가과표를 분리하고, 공동투자 시 본인 배분 후 이자를 적용한다.
6. 보수적·기준·공격적 시나리오를 구분한다.
7. 응답은 JSON 으로: {"insight":"요약 의견(200자 이내)","evidence_updates":{카테고리:{status,kind,source,detail}}}
   evidence_updates 에는 변경할 카테고리만 포함. 원문 확인 없이 pass 로 변경하지 않는다.`;

        const userPayload = {
          property: {
            title: prop.title,
            address: prop.address,
            case_no: prop.case_no,
            strategy: prop.strategy,
            district_type: prop.district_type,
            status: prop.status,
            min_price: prop.min_price,
            bid_price: prop.bid_price,
            current_price: prop.current_price,
            expected_sale_price: prop.expected_sale_price,
            jeonse_price: prop.jeonse_price,
            loan_amount: prop.loan_amount,
            acquisition_cost: prop.acquisition_cost,
            repair_cost: prop.repair_cost,
            eviction_cost: prop.eviction_cost,
            other_cost: prop.other_cost,
            sale_cost: prop.sale_cost,
            finance_cost: prop.finance_cost,
            target_profit: prop.target_profit,
            memo: prop.memo,
            checks: prop.checks,
            checklist: prop.checklist,
          },
          knowledge: knowledgeSummaries.slice(0, 15),
          calc_history: calcRows.slice(0, 5).map((r: Record<string, unknown>) => ({
            label: r.label,
            inputs: r.inputs,
          })),
          current_evidence: evidence,
          prior_analysis: priorAnalysis,
        };

        const res = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openaiKey}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            temperature: 0.3,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: JSON.stringify(userPayload) },
            ],
          }),
        });

        const j = await res.json();
        const text = j?.choices?.[0]?.message?.content?.trim();
        if (text) {
          const parsed = JSON.parse(text);
          llmInsight = parsed.insight ?? null;
          // LLM 이 evidence_updates 를 줬을 때, unknown→pass 승격은 거부.
          if (parsed.evidence_updates && typeof parsed.evidence_updates === "object") {
            llmEvidence = {};
            for (const [key, val] of Object.entries(parsed.evidence_updates)) {
              if (!EVIDENCE_KEYS.includes(key as typeof EVIDENCE_KEYS[number])) continue;
              const item = val as EvidenceItem;
              // 기존이 unknown 인데 LLM 이 pass 로 올리려 하면 차단.
              if (evidence[key]?.status === "unknown" && item.status === "pass") {
                llmEvidence[key] = { ...item, status: "unknown", detail: `(LLM 추론) ${item.detail ?? ""}` };
              } else {
                llmEvidence[key] = item;
              }
            }
          }
        }
      } catch (_) {
        // LLM 실패 시 규칙 기반 evidence 만 반환.
      }
    }

    // LLM evidence 를 기본 evidence 에 머지.
    const finalEvidence = { ...evidence };
    if (llmEvidence) {
      for (const [key, val] of Object.entries(llmEvidence)) {
        // unknown→pass 승격 재차단 (방어적).
        if (finalEvidence[key]?.status === "unknown" && val.status === "pass") {
          continue;
        }
        finalEvidence[key] = val;
      }
    }

    const analysis = {
      version: 1,
      values: {
        strategy: prop.strategy,
        min_price: prop.min_price,
        bid_price: prop.bid_price,
        current_price: prop.current_price,
        expected_sale_price: prop.expected_sale_price,
        jeonse_price: prop.jeonse_price,
        loan_amount: prop.loan_amount,
      },
      evidence: finalEvidence,
    };

    return new Response(
      JSON.stringify({
        property_id: propertyId,
        analysis,
        insight: llmInsight,
        missing: EVIDENCE_KEYS.filter((k) => finalEvidence[k]?.status === "unknown"),
      }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
