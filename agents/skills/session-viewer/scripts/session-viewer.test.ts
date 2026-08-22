import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";
import { parseSessionDocument } from "./core/detect.ts";
import { parseJsonl } from "./core/jsonl.ts";
import { resolveFleetDeliveryCommand } from "./deliver-html.ts";

const execFileAsync = promisify(execFile);

function parse(text: string) {
  const { records } = parseJsonl(text);
  return parseSessionDocument(records, "fixture.jsonl");
}

test("passes hostile paths to Fleet without a command shell", () => {
  for (const filePath of [
    "C:\\Reports\\session & calc.exe.html",
    "C:\\Reports\\session | whoami.html",
    "C:\\Reports\\%COMSPEC%.html",
    "C:\\Reports\\session ^& echo injected.html",
  ]) {
    assert.deepEqual(resolveFleetDeliveryCommand(filePath, "20260822T120000123Z"), {
      executable: "fleet",
      args: [
        "mac",
        "put",
        "--open",
        filePath,
        "/tmp/session-viewer-20260822T120000123Z",
      ],
    });
  }
});

test("parses Codex rollout tool calls and outputs", () => {
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session", cwd: "/tmp/project" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "hello" }],
        },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:02Z",
        type: "response_item",
        payload: {
          type: "function_call",
          name: "functions.exec_command",
          call_id: "call-1",
          arguments: JSON.stringify({ cmd: "pwd" }),
        },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:03Z",
        type: "response_item",
        payload: {
          type: "function_call_output",
          call_id: "call-1",
          output: "Process exited with code 0\nOutput:\n/tmp/project",
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.format, "codex");
  assert.equal(
    doc.events.some((event) => event.kind === "tool_call"),
    true,
  );
  assert.equal(
    doc.events.some((event) => event.kind === "tool_result" && event.status === "ok"),
    true,
  );
});

test("hides encrypted Codex reasoning items", () => {
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "reasoning",
          id: "rs_1",
          encrypted_content: "gAAAAABhidden",
          summary: [],
        },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:02Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "visible" }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(
    doc.events.some((event) => event.kind === "reasoning"),
    false,
  );
  assert.equal(
    doc.events
      .map((event) => event.text)
      .join("\n")
      .includes("encrypted"),
    false,
  );
});

test("collapses Codex turn-aborted markers into one concise event", () => {
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [
            {
              type: "input_text",
              text: [
                "<turn_aborted>",
                "The user interrupted the previous turn on purpose. Any running unified exec processes may still be running in the background.",
                "</turn_aborted>",
              ].join("\n"),
            },
          ],
        },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:02Z",
        type: "event_msg",
        payload: {
          type: "turn_aborted",
          reason: "interrupted",
          duration_ms: 277039,
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.filter((event) => event.title === "Turn aborted").length, 1);
  assert.equal(
    doc.events.some((event) => event.kind === "message"),
    false,
  );
  assert.equal(doc.events[0]?.text, "Turn aborted by user.");
});

test("keeps Codex turn-aborted-shaped messages without event rows", () => {
  const marker = "<turn_aborted>\nExample only.\n</turn_aborted>";
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [{ type: "input_text", text: marker }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 1);
  assert.equal(doc.events[0]?.kind, "message");
  assert.equal(doc.events[0]?.text, marker);
});

test("collapses memory citations into memory notes", () => {
  const citation = [
    "<oai-mem-citation>",
    "<citation_entries>",
    "MEMORY.md:89-97|note=[checked prior transcript-import context]",
    "</citation_entries>",
    "<rollout_ids>",
    "019e5515-7528-7393-80a4-d7a70dcb8e37",
    "</rollout_ids>",
    "</oai-mem-citation>",
  ].join("\n");
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: `Done.\n\n${citation}` }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 2);
  assert.equal(doc.events[0]?.kind, "message");
  assert.equal(doc.events[0]?.text, "Done.");
  assert.equal(doc.events[1]?.kind, "memory");
  assert.equal(doc.events[1]?.title, "Memory note");
  assert.equal(doc.events[1]?.text.includes("<oai-mem-citation>"), true);
});

test("keeps quoted memory citation examples in transcript text", () => {
  const citation = "<oai-mem-citation>example</oai-mem-citation>";
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [{ type: "input_text", text: `Please render ${citation} literally.` }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 1);
  assert.equal(doc.events[0]?.kind, "message");
  assert.equal(doc.events[0]?.text.includes(citation), true);
});

test("only splits trailing memory citation footers", () => {
  const quoted = "<oai-mem-citation>quoted</oai-mem-citation>";
  const footer = "<oai-mem-citation>footer</oai-mem-citation>";
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [
            { type: "output_text", text: `Quoted example: ${quoted}\n\nDone.\n\n${footer}` },
          ],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 2);
  assert.equal(doc.events[0]?.text.includes(quoted), true);
  assert.equal(doc.events[0]?.text.includes(footer), false);
  assert.equal(doc.events[1]?.kind, "memory");
  assert.equal(doc.events[1]?.text, footer);
});

test("renders Codex image blocks as message attachments", () => {
  const image = "data:image/png;base64,iVBORw0KGgo=";
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [
            { type: "input_text", text: "<image name=[Image #1]>" },
            { type: "input_image", image_url: { url: image }, detail: "high" },
            { type: "input_text", text: "</image>" },
            { type: "input_text", text: "[Image #1] can we show the image?" },
          ],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "can we show the image?");
  assert.equal(event?.images?.length, 1);
  assert.equal(event?.images?.[0]?.src, image);
  assert.equal(event?.images?.[0]?.detail, "high");
});

test("keeps literal image tags when no image block exists", () => {
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: 'Use <image href="x.png"></image> in XML.' }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(
    doc.events.find((item) => item.kind === "message")?.text,
    'Use <image href="x.png"></image> in XML.',
  );
});

test("keeps literal image tags beside image attachments", () => {
  const image = "data:image/png;base64,iVBORw0KGgo=";
  const doc = parse(
    [
      JSON.stringify({
        timestamp: "2026-05-25T10:00:00Z",
        type: "session_meta",
        payload: { id: "codex-session" },
      }),
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [
            { type: "input_image", image_url: image },
            { type: "input_text", text: 'Use <image href="x.png"></image> in XML.' },
          ],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, 'Use <image href="x.png"></image> in XML.');
  assert.equal(event?.images?.[0]?.src, image);
});

test("parses Claude Code tool use and result blocks", () => {
  const doc = parse(
    [
      JSON.stringify({ type: "summary", summary: "Fix parser" }),
      JSON.stringify({
        type: "assistant",
        timestamp: "2026-05-25T10:00:00Z",
        message: {
          role: "assistant",
          content: [
            { type: "text", text: "running ls" },
            { type: "tool_use", id: "toolu-1", name: "Bash", input: { command: "ls" } },
          ],
        },
      }),
      JSON.stringify({
        type: "user",
        timestamp: "2026-05-25T10:00:01Z",
        message: {
          role: "user",
          content: [{ type: "tool_result", tool_use_id: "toolu-1", content: "ok" }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.format, "claude");
  assert.equal(doc.title, "Fix parser");
  assert.equal(doc.events.filter((event) => event.kind === "tool_call").length, 1);
  assert.equal(doc.events.filter((event) => event.kind === "tool_result").length, 1);
});

test("keeps Claude thinking content blocks", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "assistant",
        timestamp: "2026-05-25T10:00:00Z",
        message: {
          role: "assistant",
          content: [{ type: "thinking", content: "visible thinking" }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.format, "claude");
  assert.equal(doc.events.filter((event) => event.kind === "reasoning").length, 1);
  assert.equal(doc.events.find((event) => event.kind === "reasoning")?.text, "visible thinking");
});

test("parses native Cursor Agent messages and tool blocks", () => {
  const doc = parse(
    [
      JSON.stringify({
        role: "user",
        message: { content: [{ type: "text", text: "Inspect the file" }] },
      }),
      JSON.stringify({
        role: "assistant",
        message: {
          content: [
            { type: "text", text: "I will inspect it." },
            { type: "tool_use", id: "cursor-call-1", name: "Read", input: { path: "README.md" } },
          ],
        },
      }),
      JSON.stringify({
        role: "user",
        message: {
          content: [
            {
              type: "tool_result",
              tool_use_id: "cursor-call-1",
              tool_use_result: { summary: "# dotfiles" },
            },
          ],
        },
      }),
      JSON.stringify({ type: "turn_ended", status: "success" }),
    ].join("\n"),
  );
  assert.equal(doc.format, "cursor");
  assert.equal(doc.events.filter((event) => event.kind === "message").length, 2);
  assert.equal(doc.events.find((event) => event.kind === "tool_call")?.toolName, "Read");
  assert.equal(doc.events.find((event) => event.kind === "tool_result")?.callId, "cursor-call-1");
  assert.equal(doc.events.find((event) => event.title === "turn ended")?.status, "ok");
});

test("parses Cursor stream-json metadata, thinking deltas, and tool lifecycle", () => {
  const sessionId = "cursor-session-id";
  const doc = parse(
    [
      JSON.stringify({
        type: "system",
        subtype: "init",
        apiKeySource: "login",
        cwd: "/tmp/project",
        model: "Auto",
        permissionMode: "default",
        session_id: sessionId,
      }),
      JSON.stringify({
        type: "user",
        session_id: sessionId,
        message: { role: "user", content: [{ type: "text", text: "Read the file" }] },
      }),
      JSON.stringify({
        type: "thinking",
        subtype: "delta",
        text: "Inspect ",
        timestamp_ms: 1_788_000_000_000,
        session_id: sessionId,
      }),
      JSON.stringify({
        type: "thinking",
        subtype: "delta",
        text: "the file.",
        timestamp_ms: 1_788_000_000_100,
        session_id: sessionId,
      }),
      JSON.stringify({
        type: "thinking",
        subtype: "completed",
        timestamp_ms: 1_788_000_000_200,
        session_id: sessionId,
      }),
      JSON.stringify({
        type: "tool_call",
        subtype: "started",
        session_id: sessionId,
        tool_call: {
          readToolCall: { args: { path: "README.md" } },
          toolCallId: "cursor-tool-1",
        },
      }),
      JSON.stringify({
        type: "tool_call",
        subtype: "completed",
        session_id: sessionId,
        tool_call: {
          readToolCall: {
            args: { path: "README.md" },
            result: { success: { content: "# dotfiles" } },
          },
          toolCallId: "cursor-tool-1",
        },
      }),
      JSON.stringify({
        type: "assistant",
        session_id: sessionId,
        message: { role: "assistant", content: [{ type: "text", text: "# dotfiles" }] },
      }),
      JSON.stringify({
        type: "result",
        subtype: "success",
        is_error: false,
        duration_ms: 1200,
        usage: { inputTokens: 100, outputTokens: 20 },
        session_id: sessionId,
      }),
    ].join("\n"),
  );
  assert.equal(doc.format, "cursor");
  assert.equal(doc.title, sessionId);
  assert.equal(doc.meta.cwd, "/tmp/project");
  assert.equal(doc.meta.input_tokens, 100);
  assert.equal(doc.events.find((event) => event.kind === "reasoning")?.text, "Inspect the file.");
  assert.equal(doc.events.filter((event) => event.kind === "tool_call").length, 1);
  assert.equal(doc.events.find((event) => event.kind === "tool_result")?.status, "ok");
});

test("parses native and dispatched Grok chat history", () => {
  const doc = parse(
    [
      JSON.stringify({ type: "system", content: "Grok system prompt" }),
      JSON.stringify({
        type: "user",
        synthetic_reason: "system_reminder",
        content: [{ type: "text", text: "Injected context" }],
      }),
      JSON.stringify({
        type: "user",
        prompt_index: 0,
        content: [{ type: "text", text: "Inspect the transcript" }],
      }),
      JSON.stringify({
        type: "reasoning",
        id: "rs-1",
        summary: [{ type: "summary_text", text: "I should inspect it." }],
        encrypted_content: "must-not-render",
        status: "completed",
      }),
      JSON.stringify({
        type: "assistant",
        content: "I will read the file.",
        tool_calls: [
          {
            id: "call-1",
            name: "read_file",
            arguments: JSON.stringify({ target_file: "session.jsonl" }),
          },
        ],
        model_id: "grok-4.6-build",
        reasoning_effort: "high",
      }),
      JSON.stringify({
        type: "tool_result",
        tool_call_id: "call-1",
        content: "file contents",
      }),
      JSON.stringify({ type: "assistant", content: "The transcript is readable." }),
    ].join("\n"),
  );

  assert.equal(doc.format, "grok");
  assert.equal(doc.meta.model, "grok-4.6-build");
  assert.equal(doc.meta.reasoning_effort, "high");
  assert.equal(
    doc.events.some(
      (event) => event.kind === "message" && event.role === "user" && event.text.includes("Inspect"),
    ),
    true,
  );
  assert.equal(doc.events.filter((event) => event.kind === "tool_call").length, 1);
  assert.equal(doc.events.filter((event) => event.kind === "tool_result").length, 1);
  assert.equal(doc.events.filter((event) => event.kind === "reasoning").length, 1);
  assert.equal(
    doc.events.some((event) => event.text.includes("must-not-render")),
    false,
  );
});

test("recognizes an incomplete native Grok session before an indexed prompt exists", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "system",
        content: "You are Grok 4.6 released by xAI.",
      }),
      JSON.stringify({
        type: "user",
        content: [{ type: "text", text: "Build the requested feature" }],
      }),
    ].join("\n"),
  );

  assert.equal(doc.format, "grok");
  assert.equal(
    doc.events.some(
      (event) =>
        event.kind === "message" &&
        event.role === "user" &&
        event.text === "Build the requested feature",
    ),
    true,
  );
});

test("parses Pi/OpenClaw message and tool result entries", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
        timestamp: "2026-05-25T10:00:00Z",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "assistant",
          content: [
            { type: "text", text: "I will check." },
            { type: "toolCall", id: "call-1", name: "read", arguments: { path: "a.ts" } },
          ],
        },
      }),
      JSON.stringify({
        type: "message",
        id: "m2",
        message: {
          role: "toolResult",
          toolCallId: "call-1",
          toolName: "read",
          content: [{ type: "text", text: "contents" }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.format, "pi-openclaw");
  assert.equal(
    doc.events.some((event) => event.kind === "message" && event.text.includes("check")),
    true,
  );
  assert.equal(
    doc.events.some((event) => event.kind === "tool_call"),
    true,
  );
  assert.equal(
    doc.events.some((event) => event.kind === "tool_result"),
    true,
  );
});

test("keeps Pi/OpenClaw numeric message timestamps", () => {
  const doc = parse(
    JSON.stringify({
      type: "message",
      id: "m1",
      message: { role: "assistant", timestamp: 1748165000000, content: [{ type: "text", text: "ok" }] },
    }),
  );
  assert.equal(doc.format, "pi-openclaw");
  assert.equal(doc.events[0]?.timestamp, "2025-05-25T09:23:20.000Z");
});

test("drops out-of-range Pi/OpenClaw numeric message timestamps", () => {
  for (const timestamp of [1e300, Number.NaN, Number.POSITIVE_INFINITY, -8.64e15 - 1]) {
    const doc = parse(
      JSON.stringify({
        type: "message",
        id: "m1",
        message: { role: "assistant", timestamp, content: [{ type: "text", text: "ok" }] },
      }),
    );
    assert.equal(doc.format, "pi-openclaw");
    assert.equal(doc.events.length, 1);
    assert.equal(doc.events[0]?.timestamp, undefined);
  }
});

test("parses Pi/OpenClaw direct image data blocks", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: [
            { type: "image", data: "iVBORw0KGgo=", mimeType: "image/png" },
            { type: "text", text: "screenshot" },
          ],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "screenshot");
  assert.equal(event?.images?.[0]?.src, "data:image/png;base64,iVBORw0KGgo=");
});

test("keeps Pi/OpenClaw relative media URL image-only turns", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: [{ type: "image", url: "/api/chat/media/image-1.png" }],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "");
  assert.equal(event?.images?.[0]?.src, "/api/chat/media/image-1.png");
});

test("keeps Pi/OpenClaw protocol-relative media URL image-only turns", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: [{ type: "image", url: "//cdn.example.test/photo.webp" }],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "");
  assert.equal(event?.images?.[0]?.src, "//cdn.example.test/photo.webp");
});

test("keeps Pi/OpenClaw bare relative media path image-only turns", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: [{ type: "image", url: "media/inbound/photo.png" }],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "");
  assert.equal(event?.images?.[0]?.src, "media/inbound/photo.png");
});

test("rejects active-scheme image URLs", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: [{ type: "image", url: "javascript:alert(1).png" }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 0);
});

test("keeps Pi/OpenClaw message-level media path image-only turns", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: "",
          MediaPaths: ["/tmp/a.png"],
          MediaTypes: ["image/png"],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "");
  assert.equal(event?.images?.[0]?.src, "/tmp/a.png");
});

test("keeps Pi/OpenClaw message-level media URL image-only turns", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: "",
          MediaUrls: ["https://example.com/photo.png"],
          MediaUrl: "https://example.com/photo.png",
          MediaTypes: ["image/png"],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.text, "");
  assert.equal(event?.images?.length, 1);
  assert.equal(event?.images?.[0]?.src, "https://example.com/photo.png");
});

test("keeps Pi/OpenClaw media refs aligned with media types", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: "",
          MediaPaths: ["", "/tmp/photo.png"],
          MediaUrls: ["https://cdn.example/audio.mp3", "/tmp/photo.png"],
          MediaTypes: ["audio/mpeg", "image/png"],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.images?.length, 1);
  assert.equal(event?.images?.[0]?.src, "/tmp/photo.png");
  assert.equal(event?.images?.[0]?.detail, "image/png");
});

test("does not apply shifted Pi/OpenClaw media types to earlier refs", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: "",
          MediaPaths: ["audio.bin", "photo.bin"],
          MediaTypes: ["image/png"],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 0);
});

test("rejects active-scheme Pi/OpenClaw message-level media refs", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: "",
          MediaPath: "javascript:alert(1).png",
          MediaType: "image/png",
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.events.length, 0);
});

test("keeps Windows Pi/OpenClaw message-level image paths", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "user",
          content: "",
          MediaPath: "C:\\OpenClaw QA\\photo.png",
          MediaType: "image/png",
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "message");
  assert.equal(event?.images?.[0]?.src, "C:\\OpenClaw QA\\photo.png");
});

test("parses Pi/OpenClaw tool result image blocks", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "toolResult",
          toolCallId: "call-1",
          content: [
            { type: "image", data: "iVBORw0KGgo=", mimeType: "image/png" },
            { type: "text", text: "generated" },
          ],
        },
      }),
    ].join("\n"),
  );
  const event = doc.events.find((item) => item.kind === "tool_result");
  assert.equal(event?.text, "generated");
  assert.equal(event?.images?.[0]?.src, "data:image/png;base64,iVBORw0KGgo=");
});

test("keeps visible Pi/OpenClaw thinking blocks", () => {
  const doc = parse(
    [
      JSON.stringify({
        type: "session",
        id: "openclaw-session",
      }),
      JSON.stringify({
        type: "message",
        id: "m1",
        message: {
          role: "assistant",
          content: [{ type: "thinking", thinking: "visible reasoning" }],
        },
      }),
    ].join("\n"),
  );
  assert.equal(doc.format, "pi-openclaw");
  assert.equal(doc.events.filter((event) => event.kind === "reasoning").length, 1);
  assert.equal(doc.events.find((event) => event.kind === "reasoning")?.text, "visible reasoning");
});

test("CLI writes a one-file HTML export", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "session-viewer-"));
  const input = path.join(dir, "session.jsonl");
  const output = path.join(dir, "session.html");
  await fs.writeFile(
    input,
    JSON.stringify({
      timestamp: "2026-05-25T10:00:00Z",
      type: "session_meta",
      payload: { id: "codex-session", cwd: dir },
    }) +
      "\n" +
      JSON.stringify({
        timestamp: "2026-05-25T10:00:01Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "exported" }],
        },
      }) +
      "\n",
    "utf8",
  );
  await execFileAsync(process.execPath, [
    "agents/skills/session-viewer/scripts/session-viewer.ts",
    input,
    "--out",
    output,
  ]);
  const html = await fs.readFile(output, "utf8");
  assert.match(html, /Session Viewer/);
  assert.match(html, /viewer-payload/);
  const payload = /<script id="viewer-payload" type="application\/json">([^<]*)<\/script>/u.exec(
    html,
  )?.[1];
  assert.ok(payload);
  assert.equal(JSON.parse(payload).kind, "normalized");
});

test("CLI accepts Grok directories, summaries, and chat history", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "session-viewer-grok-"));
  const sessionDir = path.join(dir, "grok-session-id");
  const summaryPath = path.join(sessionDir, "summary.json");
  const chatPath = path.join(sessionDir, "chat_history.jsonl");
  await fs.mkdir(sessionDir);
  await fs.writeFile(
    summaryPath,
    JSON.stringify({ info: { id: "grok-session-id", cwd: dir } }),
    "utf8",
  );
  await fs.writeFile(
    chatPath,
    [
      JSON.stringify({ type: "system", content: "Grok system prompt" }),
      JSON.stringify({
        type: "user",
        prompt_index: 0,
        content: [{ type: "text", text: "Find this Grok prompt" }],
      }),
      JSON.stringify({ type: "assistant", content: "Find this Grok response" }),
    ].join("\n"),
    "utf8",
  );

  for (const [index, input] of [sessionDir, summaryPath, chatPath].entries()) {
    const output = path.join(dir, `grok-${index}.html`);
    await execFileAsync(process.execPath, [
      "agents/skills/session-viewer/scripts/session-viewer.ts",
      input,
      "--out",
      output,
    ]);
    const html = await fs.readFile(output, "utf8");
    const payload = /<script id="viewer-payload" type="application\/json">([^<]*)<\/script>/u.exec(
      html,
    )?.[1];
    assert.ok(payload);
    const encoded = JSON.parse(payload).data;
    const document = JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
    assert.equal(document.format, "grok");
    assert.equal(document.title, "grok-session-id");
    assert.equal(
      document.events.some(
        (event: { text: string }) => event.text.includes("Find this Grok response"),
      ),
      true,
    );
  }
});

test("CLI accepts a native Cursor transcript directory", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "session-viewer-cursor-"));
  const sessionId = "cursor-session-id";
  const sessionDir = path.join(root, sessionId);
  const transcriptPath = path.join(sessionDir, `${sessionId}.jsonl`);
  const output = path.join(root, "cursor.html");
  await fs.mkdir(sessionDir);
  await fs.writeFile(
    transcriptPath,
    [
      JSON.stringify({
        role: "user",
        message: { content: [{ type: "text", text: "Find this Cursor prompt" }] },
      }),
      JSON.stringify({
        role: "assistant",
        message: { content: [{ type: "text", text: "Find this Cursor response" }] },
      }),
      JSON.stringify({ type: "turn_ended", status: "success" }),
    ].join("\n"),
    "utf8",
  );

  await execFileAsync(process.execPath, [
    "agents/skills/session-viewer/scripts/session-viewer.ts",
    sessionDir,
    "--out",
    output,
  ]);
  const html = await fs.readFile(output, "utf8");
  const payload = /<script id="viewer-payload" type="application\/json">([^<]*)<\/script>/u.exec(
    html,
  )?.[1];
  assert.ok(payload);
  const encoded = JSON.parse(payload).data;
  const document = JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
  assert.equal(document.format, "cursor");
  assert.equal(document.title, sessionId);
  assert.equal(
    document.events.some(
      (event: { text: string }) => event.text.includes("Find this Cursor response"),
    ),
    true,
  );
});

test("CLI defaults to temp output and waits for Fleet delivery on --open", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "session-viewer-fleet-"));
  const fleetLog = path.join(dir, "fleet.log");
  const fleetPath = path.join(dir, "fleet");
  await fs.writeFile(
    fleetPath,
    '#!/bin/sh\nprintf "%s\\n" "$@" > "$FLEET_LOG"\n',
    "utf8",
  );
  await fs.chmod(fleetPath, 0o755);

  const { stdout } = await execFileAsync(
    process.execPath,
    ["agents/skills/session-viewer/scripts/session-viewer.ts", "--blank", "--open"],
    {
      env: {
        ...process.env,
        FLEET_LOG: fleetLog,
        PATH: `${dir}${path.delimiter}${process.env.PATH ?? ""}`,
      },
    },
  );

  const outputPath = /^wrote: (.+)$/mu.exec(stdout)?.[1];
  assert.ok(outputPath);
  assert.equal(path.dirname(outputPath), os.tmpdir());
  const timestamp = /^session-viewer-(\d{8}T\d{9}Z)\.html$/u.exec(
    path.basename(outputPath),
  )?.[1];
  assert.ok(timestamp);
  assert.match(await fs.readFile(outputPath, "utf8"), /Session Viewer/);
  assert.deepEqual((await fs.readFile(fleetLog, "utf8")).trim().split("\n"), [
    "mac",
    "put",
    "--open",
    outputPath,
    `/tmp/session-viewer-${timestamp}`,
  ]);
});
