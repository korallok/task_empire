import {
  extractOutputText,
  handleRequest,
  validateAssessment,
} from "./index.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("validateAssessment accepts a strict valid assessment", () => {
  const result = validateAssessment({
    approvedDifficulty: "B",
    reason: "Требуется несколько часов сосредоточенной работы.",
  });

  assert(result.approvedDifficulty === "B", "difficulty should be preserved");
  assert(result.reason.startsWith("Требуется"), "reason should be preserved");
});

Deno.test("validateAssessment rejects unknown ranks and empty reasons", () => {
  for (
    const value of [
      { approvedDifficulty: "X", reason: "Reason" },
      { approvedDifficulty: "E", reason: "   " },
    ]
  ) {
    let didThrow = false;
    try {
      validateAssessment(value);
    } catch {
      didThrow = true;
    }
    assert(didThrow, "invalid assessment should throw");
  }
});

Deno.test("extractOutputText supports nested Responses API output", () => {
  const result = extractOutputText({
    output: [{
      type: "message",
      content: [{ type: "output_text", text: '{"ok":true}' }],
    }],
  });

  assert(result === '{"ok":true}', "nested output text should be returned");
});

Deno.test("handler rejects unsupported methods without touching services", async () => {
  const response = await handleRequest(
    new Request("https://example.test", {
      method: "GET",
    }),
  );
  const payload = await response.json();

  assert(response.status === 405, "GET should return 405");
  assert(
    payload.error?.code === "METHOD_NOT_ALLOWED",
    "response should include a stable error code",
  );
});

Deno.test("handler rejects missing bearer tokens", async () => {
  const response = await handleRequest(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        taskId: "00000000-0000-4000-8000-000000000001",
      }),
      headers: { "Content-Type": "application/json" },
    }),
  );
  const payload = await response.json();

  assert(response.status === 401, "missing token should return 401");
  assert(
    payload.error?.code === "UNAUTHORIZED",
    "response should include the authentication error code",
  );
});
