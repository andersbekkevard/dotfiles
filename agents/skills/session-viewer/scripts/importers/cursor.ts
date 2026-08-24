import {
  compactText,
  expandMemoryCitationEvents,
  firstText,
  imageAttachmentsFromContent,
  isRecord,
  numberValue,
  pretty,
  stringValue,
  textFromContentBlocks,
} from "../core/jsonl.ts";
import type { JsonlRecord, SessionDocument, SessionEvent, SessionImporter } from "../core/types.ts";

function timestampOf(value: Record<string, unknown>): string | undefined {
  const timestamp = stringValue(value.timestamp);
  if (timestamp) {
    return timestamp;
  }
  const milliseconds = numberValue(value.timestamp_ms);
  if (milliseconds === undefined) {
    return undefined;
  }
  const date = new Date(milliseconds);
  return Number.isNaN(date.valueOf()) ? undefined : date.toISOString();
}

function titleFromSource(sourcePath: string | undefined): string {
  if (!sourcePath) {
    return "Cursor session";
  }
  const basename = sourcePath.split(/[\\/]/u).filter(Boolean).at(-1) ?? "Cursor session";
  return basename.endsWith(".jsonl") ? basename.slice(0, -".jsonl".length) : basename;
}

function contentEvents(
  record: JsonlRecord,
  role: string,
  content: unknown,
  timestamp: string | undefined,
): SessionEvent[] {
  if (typeof content === "string") {
    return content.trim()
      ? [{
          id: `cursor-${record.line}`,
          kind: "message",
          role,
          title: role,
          text: content.trim(),
          timestamp,
          raw: record.value,
        }]
      : [];
  }
  if (!Array.isArray(content)) {
    return [];
  }

  const events: SessionEvent[] = [];
  const textParts: string[] = [];
  const images = imageAttachmentsFromContent(content);
  for (const [index, block] of content.entries()) {
    if (!isRecord(block)) {
      continue;
    }
    const type = stringValue(block.type) ?? "unknown";
    if (type === "text") {
      const text = stringValue(block.text);
      if (text) {
        textParts.push(text);
      }
      continue;
    }
    if (type === "thinking") {
      const text = firstText(block, ["thinking", "text", "content"]);
      if (text) {
        events.push({
          id: `cursor-${record.line}-thinking-${index}`,
          kind: "reasoning",
          title: "thinking",
          text,
          timestamp,
          raw: block,
        });
      }
      continue;
    }
    if (type === "tool_result" || type === "tool_use_result") {
      const callId = stringValue(block.tool_use_id) ?? stringValue(block.id);
      const output = block.content ?? block.output ?? block.tool_use_result ?? block;
      const resultImages = imageAttachmentsFromContent(output);
      events.push({
        id: `cursor-${record.line}-result-${index}`,
        kind: "tool_result",
        title: callId ? `tool result: ${callId}` : "tool result",
        text: textFromContentBlocks(output) || (resultImages.length ? "" : pretty(output)),
        images: resultImages.length ? resultImages : undefined,
        timestamp,
        callId,
        toolName: stringValue(block.name),
        status: block.is_error === true ? "error" : "ok",
        raw: block,
      });
      continue;
    }
    if (type === "tool_use" || type.toLowerCase().includes("tool")) {
      const name = stringValue(block.name) ?? type;
      events.push({
        id: `cursor-${record.line}-tool-${index}`,
        kind: "tool_call",
        title: `tool call: ${name}`,
        text: pretty(block.input ?? block.arguments ?? {}),
        timestamp,
        callId: stringValue(block.id) ?? stringValue(block.tool_use_id),
        toolName: name,
        status: "running",
        raw: block,
      });
    }
  }

  const text = compactText(textParts);
  if (text || images.length) {
    events.unshift({
      id: `cursor-${record.line}-text`,
      kind: "message",
      role,
      title: role,
      text,
      images: images.length ? images : undefined,
      timestamp,
      raw: record.value,
    });
  }
  return events;
}

function streamTool(
  value: Record<string, unknown>,
): { callId?: string; input: unknown; name: string; output: unknown } | null {
  if (!isRecord(value.tool_call)) {
    return null;
  }
  const envelope = value.tool_call;
  const entry = Object.entries(envelope).find(
    ([key, item]) => key.endsWith("ToolCall") && isRecord(item),
  );
  const payload = entry && isRecord(entry[1]) ? entry[1] : undefined;
  const rawName = entry?.[0]?.replace(/ToolCall$/u, "") ?? "tool";
  const name = rawName.replace(/([a-z0-9])([A-Z])/gu, "$1 $2").toLowerCase();
  return {
    callId: stringValue(envelope.toolCallId),
    input: payload?.args ?? {},
    name,
    output: payload?.result ?? payload,
  };
}

export const cursorImporter: SessionImporter = {
  format: "cursor",
  detect(records) {
    return records.some((record) => {
      if (!isRecord(record.value)) {
        return false;
      }
      const value = record.value;
      return (
        value.type === "turn_ended" ||
        (typeof value.role === "string" && isRecord(value.message)) ||
        (value.type === "tool_call" && isRecord(value.tool_call)) ||
        (value.type === "system" &&
          value.subtype === "init" &&
          typeof value.session_id === "string" &&
          "apiKeySource" in value &&
          !("claude_code_version" in value))
      );
    });
  },
  parse(records, sourcePath) {
    const meta: SessionDocument["meta"] = {};
    const events: SessionEvent[] = [];
    const warnings: string[] = [];
    const startedCalls = new Set<string>();
    let thinking = "";
    let thinkingLine = 0;
    let thinkingTimestamp: string | undefined;

    const flushThinking = () => {
      if (!thinking) {
        return;
      }
      events.push({
        id: `cursor-${thinkingLine}-thinking`,
        kind: "reasoning",
        title: "thinking",
        text: thinking,
        timestamp: thinkingTimestamp,
      });
      thinking = "";
      thinkingLine = 0;
      thinkingTimestamp = undefined;
    };

    for (const record of records) {
      if (!isRecord(record.value)) {
        continue;
      }
      const value = record.value;
      const type = stringValue(value.type);
      const sessionId = stringValue(value.session_id);
      if (sessionId) {
        meta.id = sessionId;
      }

      if (type === "thinking") {
        if (value.subtype === "delta") {
          thinkingLine ||= record.line;
          thinkingTimestamp ??= timestampOf(value);
          thinking += stringValue(value.text) ?? "";
        } else if (value.subtype === "completed") {
          flushThinking();
        }
        continue;
      }
      flushThinking();

      if (type === "system" && value.subtype === "init") {
        const cwd = stringValue(value.cwd);
        const model = stringValue(value.model);
        const permissionMode = stringValue(value.permissionMode);
        if (cwd) meta.cwd = cwd;
        if (model) meta.model = model;
        if (permissionMode) meta.permission_mode = permissionMode;
        continue;
      }

      if (type === "tool_call") {
        const tool = streamTool(value);
        if (!tool) {
          continue;
        }
        if (value.subtype === "started" || !tool.callId || !startedCalls.has(tool.callId)) {
          events.push({
            id: `cursor-${record.line}-tool`,
            kind: "tool_call",
            title: `tool call: ${tool.name}`,
            text: pretty(tool.input),
            timestamp: timestampOf(value),
            callId: tool.callId,
            toolName: tool.name,
            status: "running",
            raw: value,
          });
          if (tool.callId) startedCalls.add(tool.callId);
        }
        if (value.subtype === "completed") {
          const output = tool.output;
          const failed = isRecord(output) && "error" in output;
          events.push({
            id: `cursor-${record.line}-result`,
            kind: "tool_result",
            title: tool.callId ? `tool result: ${tool.callId}` : "tool result",
            text: pretty(output),
            timestamp: timestampOf(value),
            callId: tool.callId,
            toolName: tool.name,
            status: failed ? "error" : "ok",
            raw: value,
          });
        }
        continue;
      }

      const message = isRecord(value.message) ? value.message : undefined;
      const role = stringValue(value.role) ?? stringValue(message?.role);
      if (message && role) {
        events.push(...contentEvents(record, role, message.content, timestampOf(value)));
        continue;
      }

      if (type === "result") {
        const usage = isRecord(value.usage) ? value.usage : undefined;
        const inputTokens = numberValue(usage?.inputTokens);
        const outputTokens = numberValue(usage?.outputTokens);
        if (inputTokens !== undefined) meta.input_tokens = inputTokens;
        if (outputTokens !== undefined) meta.output_tokens = outputTokens;
        const duration = numberValue(value.duration_ms);
        if (duration !== undefined) meta.duration_ms = duration;
        if (value.is_error === true) {
          warnings.push(`Cursor result failed: ${firstText(value, ["result"]) ?? "unknown error"}`);
        }
        continue;
      }

      if (type === "turn_ended") {
        const status = stringValue(value.status) ?? "unknown";
        events.push({
          id: `cursor-${record.line}-end`,
          kind: "event",
          title: "turn ended",
          text: status,
          status: status === "success" ? "ok" : status === "error" ? "error" : "unknown",
          raw: value,
        });
      }
    }
    flushThinking();

    if (!events.some((event) => event.kind === "message")) {
      warnings.push("no Cursor user or assistant messages found");
    }
    return {
      format: "cursor",
      title: stringValue(meta.id) ?? titleFromSource(sourcePath),
      sourcePath,
      meta,
      events: expandMemoryCitationEvents(events),
      warnings,
    };
  },
};
