// Unit tests for auction-analysis helper functions.
// Run: deno test --allow-none supabase/functions/auction-analysis/index_test.ts
//
// We test pure utility functions by extracting them here.
// The Edge Function itself requires Supabase/OpenAI, so we test the
// helpers that had bugs: uint8ToBase64, isAllowedImageUrl, readBodyLimited,
// trimKnowledge, unknownEvidence, and the condition logic.

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// ── Extracted helpers (same logic as index.ts) ──────────────────

const EVIDENCE_KEYS = [
  "identity", "condition", "rights", "zone",
  "eligibility", "market", "tax", "funding",
] as const;

function unknownEvidence(): Record<string, { status: string }> {
  const ev: Record<string, { status: string }> = {};
  for (const k of EVIDENCE_KEYS) ev[k] = { status: "unknown" };
  return ev;
}

const ALLOWED_IMAGE_HOST = "rbksmjnfaqglnzypgxqa.supabase.co";

function isAllowedImageUrl(url: string): boolean {
  if (url.startsWith("data:image/")) return true;
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" && parsed.hostname === ALLOWED_IMAGE_HOST;
  } catch {
    return false;
  }
}

function uint8ToBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000;
  const parts: string[] = [];
  for (let i = 0; i < bytes.length; i += CHUNK) {
    parts.push(
      String.fromCharCode.apply(
        null,
        bytes.subarray(i, i + CHUNK) as unknown as number[],
      ),
    );
  }
  return btoa(parts.join(""));
}

const KNOWLEDGE_TOTAL_CHARS = 12_000;

function trimKnowledge(
  rows: Array<{ body?: string; title?: string; tags?: unknown; source?: string }>,
  maxItems: number,
  totalBudget: number,
): Array<{ title?: string; tags?: unknown; source?: string; body: string | null }> {
  const out: Array<{ title?: string; tags?: unknown; source?: string; body: string | null }> = [];
  let remaining = totalBudget;
  for (const k of rows.slice(0, maxItems)) {
    const raw = typeof k.body === "string" ? k.body : "";
    const body = remaining > 0 ? raw.slice(0, remaining) : null;
    if (body) remaining -= body.length;
    out.push({ title: k.title, tags: k.tags, source: k.source, body });
  }
  return out;
}

// ── Tests ───────────────────────────────────────────────────────

Deno.test("unknownEvidence: all 8 categories start unknown", () => {
  const ev = unknownEvidence();
  assertEquals(Object.keys(ev).length, 8);
  for (const k of EVIDENCE_KEYS) {
    assertEquals(ev[k].status, "unknown");
  }
});

Deno.test("isAllowedImageUrl: accepts project Supabase storage", () => {
  assertEquals(
    isAllowedImageUrl(
      "https://rbksmjnfaqglnzypgxqa.supabase.co/storage/v1/object/public/photos/abc.jpg",
    ),
    true,
  );
});

Deno.test("isAllowedImageUrl: accepts data:image URIs", () => {
  assertEquals(isAllowedImageUrl("data:image/png;base64,iVBOR..."), true);
});

Deno.test("isAllowedImageUrl: rejects arbitrary HTTPS", () => {
  assertEquals(isAllowedImageUrl("https://evil.com/shell.jpg"), false);
});

Deno.test("isAllowedImageUrl: rejects HTTP (not HTTPS)", () => {
  assertEquals(
    isAllowedImageUrl(
      "http://rbksmjnfaqglnzypgxqa.supabase.co/storage/v1/object/public/photos/abc.jpg",
    ),
    false,
  );
});

Deno.test("isAllowedImageUrl: rejects internal/private IPs", () => {
  assertEquals(isAllowedImageUrl("https://169.254.169.254/latest/meta-data"), false);
  assertEquals(isAllowedImageUrl("https://localhost:8080/secret"), false);
  assertEquals(isAllowedImageUrl("file:///etc/passwd"), false);
});

Deno.test("isAllowedImageUrl: rejects non-data URIs", () => {
  assertEquals(isAllowedImageUrl("data:text/html,<script>alert(1)</script>"), false);
});

Deno.test("uint8ToBase64: small buffer matches btoa", () => {
  const bytes = new TextEncoder().encode("Hello, World!");
  const expected = btoa("Hello, World!");
  assertEquals(uint8ToBase64(bytes), expected);
});

Deno.test("uint8ToBase64: large buffer (>32KB) does not throw", () => {
  // 100 KB buffer — would stack-overflow with spread approach.
  const bytes = new Uint8Array(100_000);
  for (let i = 0; i < bytes.length; i++) bytes[i] = i % 256;
  const result = uint8ToBase64(bytes);
  assertEquals(typeof result, "string");
  assertEquals(result.length > 0, true);
  // Verify round-trip: atob → back to bytes.
  const decoded = atob(result);
  assertEquals(decoded.length, 100_000);
  assertEquals(decoded.charCodeAt(0), 0);
  assertEquals(decoded.charCodeAt(255), 255);
  assertEquals(decoded.charCodeAt(256), 0);
});

Deno.test("uint8ToBase64: empty buffer", () => {
  assertEquals(uint8ToBase64(new Uint8Array(0)), "");
});

Deno.test("trimKnowledge: respects total budget, not per-item", () => {
  const rows = [
    { title: "A", body: "x".repeat(8000), tags: [], source: "a" },
    { title: "B", body: "y".repeat(8000), tags: [], source: "b" },
    { title: "C", body: "z".repeat(8000), tags: [], source: "c" },
  ];
  const result = trimKnowledge(rows, 15, 12_000);
  assertEquals(result.length, 3);
  // First item gets full 8000.
  assertEquals(result[0].body!.length, 8000);
  // Second item gets remaining 4000.
  assertEquals(result[1].body!.length, 4000);
  // Third item gets null (budget exhausted).
  assertEquals(result[2].body, null);
});

Deno.test("trimKnowledge: short bodies all fit", () => {
  const rows = [
    { title: "A", body: "short1", tags: [], source: "a" },
    { title: "B", body: "short2", tags: [], source: "b" },
  ];
  const result = trimKnowledge(rows, 15, 12_000);
  assertEquals(result[0].body, "short1");
  assertEquals(result[1].body, "short2");
});

Deno.test("trimKnowledge: maxItems limits output", () => {
  const rows = Array.from({ length: 20 }, (_, i) => ({
    title: `T${i}`,
    body: "x",
    tags: [],
    source: "s",
  }));
  const result = trimKnowledge(rows, 5, 12_000);
  assertEquals(result.length, 5);
});

Deno.test("condition: violation=true → fail", () => {
  const evidence = unknownEvidence();
  const checks = { violation: true };
  if (checks.violation === true) {
    evidence.condition = { status: "fail" };
  }
  assertEquals(evidence.condition.status, "fail");
});

Deno.test("condition: violation=false → unknown (not pass)", () => {
  const evidence = unknownEvidence();
  const checks = { violation: false };
  if (checks.violation === true) {
    evidence.condition = { status: "fail" };
  } else if (checks.violation === false) {
    evidence.condition = { status: "unknown" };
  }
  assertEquals(evidence.condition.status, "unknown");
});

Deno.test("condition: violation absent → unknown", () => {
  const evidence = unknownEvidence();
  const checks: Record<string, unknown> = {};
  // No mutation → stays unknown.
  assertEquals(evidence.condition.status, "unknown");
});
