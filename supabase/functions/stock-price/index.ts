// 주식/ETF 현재가 + 최근 주당 배당(분배금) 조회.
// 야후 파이낸스 chart API 사용 (서버측이라 CORS 무관).
// 국장 6자리 코드는 자동으로 ".KS" 를 붙인다. 미장은 심볼 그대로.
// 요청: POST { "symbols": ["AGNC", "352540", ...] }
// 응답: { "AGNC": {price, currency, dividend, dividendDate}, ... }

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  let symbols: string[] = [];
  try {
    symbols = (await req.json())?.symbols ?? [];
  } catch (_) {
    symbols = [];
  }

  const out: Record<string, unknown> = {};
  await Promise.all(
    symbols.map(async (raw) => {
      const s = String(raw ?? "").trim();
      if (!s) return;
      // 6자리 숫자 = 국장 코드 → .KS
      const y = /^\d{6}$/.test(s) ? `${s}.KS` : s;
      try {
        const r = await fetch(
          `https://query1.finance.yahoo.com/v8/finance/chart/${
            encodeURIComponent(y)
          }?interval=1d&range=1y&events=div`,
          { headers: { "User-Agent": "Mozilla/5.0" } },
        );
        const j = await r.json();
        const res = j?.chart?.result?.[0];
        const m = res?.meta;
        const divs = (res?.events?.dividends ?? {}) as Record<
          string,
          { amount: number; date: number }
        >;
        let last: { amount: number; date: number } | null = null;
        for (const k in divs) {
          const d = divs[k];
          if (!last || d.date > last.date) last = d;
        }
        out[s] = {
          price: m?.regularMarketPrice ?? null,
          currency: m?.currency ?? null,
          dividend: last?.amount ?? null,
          dividendDate: last
            ? new Date(last.date * 1000).toISOString().slice(0, 10)
            : null,
        };
      } catch (_) {
        out[s] = { price: null, currency: null, dividend: null, dividendDate: null };
      }
    }),
  );

  return new Response(JSON.stringify(out), {
    headers: { ...cors, "Content-Type": "application/json" },
  });
});
