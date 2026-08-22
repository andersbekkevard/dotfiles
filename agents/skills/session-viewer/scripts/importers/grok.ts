import {
  compactText,
  expandMemoryCitationEvents,
  imageAttachmentsFromContent,
  isRecord,
  numberValue,
  pretty,
  stringValue,
  textFromContentBlocks,
} from "../core/jsonl.ts";
import type { JsonlRecord, SessionDocument, SessionEvent, SessionImporter } from "../core/types.ts";

function titleFromSource(sourcePath: string | undefined): string {
  if (!sourcePath) {
    return "Grok session";
  }
  const parts = sourcePath.split(/[\\/]/u).filter(Boolean);
  const basename = parts.at(-1);
  if (basename === "summary.json" || basename === "chat_history.jsonl") {
    return parts.at(-2) ?? "Grok session";
  }
  return basename ?? "Grok session";
}

function reasoningEvent(record: JsonlRecord, value: Record<string, unknown>): SessionEvent | null {
  const summary = Array.isArray(value.summary)
    ? compactText(
        value.summary.map((item) =>
          isRecord(item) ? stringValue(item.text) : undefined,
        ),
      )
    : "";
  if (!summary) {
    return null;
  }
  return {
    id: stringValue(value.id) ?? `grok-${record.line}`,
    kind: "reasoning",
    title: "reasoning",
    text: summary,
    raw: value,
  };
}

function assistantEvents(
  record: JsonlRecord,
  value: Record<string, unknown>,
): SessionEvent[] {
  const events: SessionEvent[] = [];
  const text = textFromContentBlocks(value.content);
  if (text) {
    events.push({
      id: `grok-${record.line}-text`,
      kind: "message",
      role: "assistant",
      title: "assistant",
      text,
      raw: value,
    });
  }
  if (Array.isArray(value.tool_calls)) {
    for (const [index, toolCall] of value.tool_calls.entries()) {
      if (!isRecord(toolCall)) {
        continue;
      }
      const name = stringValue(toolCall.name) ?? "tool";
      events.push({
        id: `grok-${record.line}-tool-${index}`,
        kind: "tool_call",
        title: `tool call: ${name}`,
        text: pretty(toolCall.arguments),
        callId: stringValue(toolCall.id),
        toolName: name,
        status: "running",
        raw: toolCall,
      });
    }
  }
  return events;
}

export const grokImporter: SessionImporter = {
  format: "grok",
  detect(records) {
    return records.some((record) => {
      if (!isRecord(record.value)) {
        return false;
      }
      return (
        numberValue(record.value.prompt_index) !== undefined ||
        (record.value.type === "system" &&
          stringValue(record.value.content)?.includes("You are Grok") === true) ||
        (record.value.type === "reasoning" && "encrypted_content" in record.value) ||
        (record.value.type === "tool_result" && "tool_call_id" in record.value) ||
        (record.value.type === "assistant" && Array.isArray(record.value.tool_calls))
      );
    });
  },
  parse(records, sourcePath) {
    const meta: SessionDocument["meta"] = {};
    const events: SessionEvent[] = [];
    const warnings: string[] = [];
    const hasIndexedPrompt = records.some(
      (record) =>
        isRecord(record.value) && numberValue(record.value.prompt_index) !== undefined,
    );
    const lastUserLine = records.findLast(
      (record) => isRecord(record.value) && record.value.type === "user",
    )?.line;

    for (const record of records) {
      if (!isRecord(record.value)) {
        continue;
      }
      const value = record.value;
      const type = stringValue(value.type);
      if (type === "system" || type === "user") {
        const text = textFromContentBlocks(value.content);
        if (!text) {
          continue;
        }
        const isPrompt =
          numberValue(value.prompt_index) !== undefined ||
          (!hasIndexedPrompt && record.line === lastUserLine);
        const syntheticReason = stringValue(value.synthetic_reason);
        events.push({
          id: `grok-${record.line}`,
          kind: type === "system" || !isPrompt ? "system" : "message",
          role: type === "system" || !isPrompt ? "system" : "user",
          title: syntheticReason?.replaceAll("_", " ") ?? (isPrompt ? "user" : "session context"),
          text,
          raw: value,
        });
        continue;
      }
      if (type === "reasoning") {
        const event = reasoningEvent(record, value);
        if (event) {
          events.push(event);
        }
        continue;
      }
      if (type === "assistant") {
        const modelId = stringValue(value.model_id);
        const effort = stringValue(value.reasoning_effort);
        if (modelId) {
          meta.model = modelId;
        }
        if (effort) {
          meta.reasoning_effort = effort;
        }
        events.push(...assistantEvents(record, value));
        continue;
      }
      if (type === "tool_result") {
        const images = imageAttachmentsFromContent(value.content);
        const text =
          textFromContentBlocks(value.content) ||
          (images.length ? "" : pretty(value.content));
        events.push({
          id: `grok-${record.line}`,
          kind: "tool_result",
          title: stringValue(value.tool_call_id)
            ? `tool result: ${stringValue(value.tool_call_id)}`
            : "tool result",
          text,
          images: images.length ? images : undefined,
          callId: stringValue(value.tool_call_id),
          status: "unknown",
          raw: value,
        });
      }
    }

    if (!events.some((event) => event.kind === "message")) {
      warnings.push("no Grok user or assistant messages found");
    }
    return {
      format: "grok",
      title: titleFromSource(sourcePath),
      sourcePath,
      meta,
      events: expandMemoryCitationEvents(events),
      warnings,
    };
  },
};
