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

function jsonRes(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Evidence 카테고리. 공개 조회 안 된 것은 unknown 유지.
const EVIDENCE_KEYS = [
  "identity",    // 물건 기본 특정 (소재지·면적·층수)
  "condition",   // 건물 상태 (위반건축물·노후도·수리 범위)
  "rights",      // 권리분석 (등기부·임차인·대항력·배당)
  "zone",        // 구역 정보 (모아타운·신통기획·정비구역 지정 여부)
  "eligibility", // 입찰 자격·조합원 자격·지분 요건
  "market",      // 시세·전세가·실거래·매물 동향
  "tax",         // 취득세·양도세·종부세 시나리오
  "funding",     // 자금 계획 (대출 가능액·필요현금·이자)
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

// ── 이미지 fetch 유틸 ──────────────────────────────────────────
const MAX_IMAGES = 3;
const IMAGE_TIMEOUT_MS = 8_000;
const MAX_IMAGE_BYTES = 2 * 1024 * 1024; // 2 MB per image

// SSRF 방지 — 이 프로젝트 Supabase storage HTTPS 만 허용.
const ALLOWED_IMAGE_HOST = "rbksmjnfaqglnzypgxqa.supabase.co";

function isAllowedImageUrl(url: string): boolean {
  // data:image URI 도 허용 (클라이언트가 직접 인코딩한 경우).
  if (url.startsWith("data:image/")) return true;
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" && parsed.hostname === ALLOWED_IMAGE_HOST;
  } catch {
    return false;
  }
}

// chunk 기반 base64 변환 — spread 로 스택 오버플로 방지.
function uint8ToBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000; // 32 KB chunks
  const parts: string[] = [];
  for (let i = 0; i < bytes.length; i += CHUNK) {
    parts.push(String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK) as unknown as number[]));
  }
  return btoa(parts.join(""));
}

async function fetchImageAsDataUri(url: string): Promise<string | null> {
  // data URI 는 fetch 하지 않고 그대로 반환.
  if (url.startsWith("data:image/")) {
    return url.length <= MAX_IMAGE_BYTES * 1.37 ? url : null; // base64 는 ~37% 팽창
  }
  if (!isAllowedImageUrl(url)) return null;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), IMAGE_TIMEOUT_MS);
    const res = await fetch(url, { signal: ctrl.signal });
    clearTimeout(timer);
    if (!res.ok) return null;
    const buf = await res.arrayBuffer();
    if (buf.byteLength > MAX_IMAGE_BYTES) return null;
    const ct = res.headers.get("content-type") ?? "image/jpeg";
    const b64 = uint8ToBase64(new Uint8Array(buf));
    return `data:${ct};base64,${b64}`;
  } catch {
    return null;
  }
}

// ── body 크기 제한 (실제 바이트 읽기) ───────────────────────────
const MAX_BODY_BYTES = 1 * 1024 * 1024;

async function readBodyLimited(req: Request): Promise<string> {
  // Content-Length 힌트가 있으면 먼저 확인 (빠른 거부).
  const cl = req.headers.get("content-length");
  if (cl && parseInt(cl) > MAX_BODY_BYTES) {
    throw new Error("TOO_LARGE");
  }
  // chunked 전송 대응 — 실제 바이트를 세며 읽는다.
  const reader = req.body?.getReader();
  if (!reader) throw new Error("TOO_LARGE");
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BODY_BYTES) {
      reader.cancel();
      throw new Error("TOO_LARGE");
    }
    chunks.push(value);
  }
  const decoder = new TextDecoder();
  return chunks.map((c) => decoder.decode(c, { stream: true })).join("") +
    decoder.decode();
}

// ── 자료실 본문 총량 제한 ───────────────────────────────────────
const KNOWLEDGE_TOTAL_CHARS = 12_000;

function trimKnowledge(
  rows: Record<string, unknown>[],
  maxItems: number,
  totalBudget: number,
): Array<{ title: unknown; tags: unknown; source: unknown; body: string | null }> {
  const out: Array<{ title: unknown; tags: unknown; source: unknown; body: string | null }> = [];
  let remaining = totalBudget;
  for (const k of rows.slice(0, maxItems)) {
    const raw = typeof k.body === "string" ? (k.body as string) : "";
    const body = remaining > 0 ? raw.slice(0, remaining) : null;
    if (body) remaining -= body.length;
    out.push({ title: k.title, tags: k.tags, source: k.source, body });
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // POST 전용.
  if (req.method !== "POST") {
    return jsonRes({ error: "method not allowed" }, 405);
  }

  try {
    // 실제 바이트를 세며 body 를 읽는다 (chunked 우회 방지).
    let rawBody: string;
    try {
      rawBody = await readBodyLimited(req);
    } catch {
      return jsonRes({ error: "request too large" }, 413);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData } = await sb.auth.getUser();
    const user = userData.user;
    if (!user) {
      return jsonRes({ error: "unauthorized" }, 401);
    }

    const body = JSON.parse(rawBody);
    const propertyId: string | undefined = body?.property_id;
    if (!propertyId) {
      return jsonRes({ error: "property_id is required" }, 400);
    }

    // ── 데이터 수집 (RLS 적용) ──────────────────────────────────
    const [propRes, knowledgeRes, calcsRes] = await Promise.all([
      sb.from("auction_properties")
        .select("*")
        .eq("id", propertyId)
        .maybeSingle(),
      sb.from("knowledge_notes")
        .select("id, title, body, tags, source, author, source_date, files")
        .overlaps("tags", ["경매", "모아타운", "신속통합", "재개발", "권리분석", "세금", "대출", "입찰"])
        .order("source_date", { ascending: false })
        .limit(30),
      // property_id AND _kind=investment.
      sb.from("calc_records")
        .select("id, label, inputs, updated_at")
        .eq("inputs->>property_id", propertyId)
        .eq("inputs->>_kind", "investment")
        .order("updated_at", { ascending: false })
        .limit(20),
    ]);

    const prop = propRes.data;
    if (!prop) {
      return jsonRes({ error: "property not found" }, 404);
    }

    // 자료실 — 총량 제한으로 핵심 전략이 잘리지 않게 한다.
    const knowledgeSummaries = trimKnowledge(
      knowledgeRes.data ?? [],
      15,
      KNOWLEDGE_TOTAL_CHARS,
    );

    const calcRows = calcsRes.data ?? [];
    const priorAnalysis = body?.analysis ?? null;

    // ── evidence 초기화 — 전부 unknown ─────────────────────────
    // 원문 확인 없이 pass 를 생성하지 않는다.
    const evidence = unknownEvidence();

    // condition: 위반건축물이 명시적으로 true 일 때만 fail.
    // false 도 원문 검증이 아니므로 unknown (detail 에 기록).
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
        status: "unknown",
        kind: "위반건축물 미감지",
        source: "auction_properties.checks",
        checked_on: prop.updated_at,
        detail: "앱 입력에서 위반건축물 미감지 — 원문(건축물대장) 확인 필요",
      };
    }

    // ── 이미지 수집 (SSRF 방지 + chunk 변환) ────────────────────
    const imageUrls: string[] = Array.isArray(prop.images)
      ? (prop.images as string[]).filter(isAllowedImageUrl).slice(0, MAX_IMAGES)
      : [];
    const imageDataUris = (
      await Promise.all(imageUrls.map(fetchImageAsDataUri))
    ).filter((u): u is string => u !== null);

    // ── LLM 분석 ───────────────────────────────────────────────
    const openaiKey = Deno.env.get("OPENAI_API_KEY");

    let llmInsight: string | null = null;
    let llmEvidence: Record<string, EvidenceItem> | null = null;
    let llmStatus: "ok" | "not_configured" | "failed" = "not_configured";

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
7. 사진이 첨부돼 있으면 건물 상태·외관·노후도·주변 환경을 분석한다.
8. 응답은 JSON 으로: {"insight":"요약 의견(200자 이내)","evidence_updates":{카테고리:{status,kind,source,detail}}}
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
          knowledge: knowledgeSummaries,
          calc_history: calcRows.slice(0, 5).map((r: Record<string, unknown>) => ({
            label: r.label,
            inputs: r.inputs,
          })),
          current_evidence: evidence,
          prior_analysis: priorAnalysis,
        };

        const userContent: Array<{ type: string; text?: string; image_url?: { url: string } }> = [
          { type: "text", text: JSON.stringify(userPayload) },
        ];
        for (const dataUri of imageDataUris) {
          userContent.push({
            type: "image_url",
            image_url: { url: dataUri },
          });
        }

        const ctrl = new AbortController();
        const timer = setTimeout(() => ctrl.abort(), 30_000);
        const res = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openaiKey}`,
          },
          signal: ctrl.signal,
          body: JSON.stringify({
            model: imageDataUris.length > 0 ? "gpt-4o" : "gpt-4o-mini",
            temperature: 0.3,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: userContent },
            ],
          }),
        });
        clearTimeout(timer);

        if (!res.ok) {
          llmStatus = "failed";
          llmInsight = `LLM API error: ${res.status}`;
        } else {
          const j = await res.json();
          const text = j?.choices?.[0]?.message?.content?.trim();
          if (text) {
            const parsed = JSON.parse(text);
            llmInsight = parsed.insight ?? null;
            llmStatus = "ok";
            if (parsed.evidence_updates && typeof parsed.evidence_updates === "object") {
              llmEvidence = {};
              for (const [key, val] of Object.entries(parsed.evidence_updates)) {
                if (!EVIDENCE_KEYS.includes(key as typeof EVIDENCE_KEYS[number])) continue;
                const item = val as EvidenceItem;
                if (evidence[key]?.status === "unknown" && item.status === "pass") {
                  llmEvidence[key] = { ...item, status: "unknown", detail: `(LLM 추론) ${item.detail ?? ""}` };
                } else {
                  llmEvidence[key] = item;
                }
              }
            }
          } else {
            llmStatus = "failed";
          }
        }
      } catch (e) {
        llmStatus = "failed";
        llmInsight = `LLM error: ${e instanceof Error ? e.message : String(e)}`;
      }
    }

    // LLM evidence 머지 — unknown→pass 승격 재차단.
    const finalEvidence = { ...evidence };
    if (llmEvidence) {
      for (const [key, val] of Object.entries(llmEvidence)) {
        if (finalEvidence[key]?.status === "unknown" && val.status === "pass") {
          continue;
        }
        finalEvidence[key] = val;
      }
    }

    // ── 응답 — body.analysis.values 보존 ────────────────────────
    const callerValues = priorAnalysis?.values ?? {};

    const analysis = {
      version: 1,
      values: callerValues,
      evidence: finalEvidence,
    };

    return jsonRes({
      property_id: propertyId,
      analysis,
      insight: llmInsight,
      llm_status: llmStatus,
      images_analyzed: imageDataUris.length,
      missing: EVIDENCE_KEYS.filter((k) => finalEvidence[k]?.status === "unknown"),
    });
  } catch (e) {
    return jsonRes({ error: String(e) }, 500);
  }
});
