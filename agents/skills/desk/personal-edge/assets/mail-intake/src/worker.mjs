const OBJECT_PREFIX = "incoming/v1";
const SUBJECT_METADATA_BYTES = 512;
const MESSAGE_ID_METADATA_BYTES = 256;

function truncateUtf8(value, maxBytes) {
  const text = String(value ?? "");
  const encoder = new TextEncoder();
  if (encoder.encode(text).byteLength <= maxBytes) return text;

  let result = "";
  for (const character of text) {
    const candidate = `${result}${character}`;
    if (encoder.encode(candidate).byteLength > maxBytes) break;
    result = candidate;
  }
  return result;
}

export function normalizeRecipient(value) {
  const recipient = String(value ?? "").trim().toLowerCase();
  if (!recipient || !recipient.includes("@")) {
    throw new Error("mail intake requires a valid envelope recipient");
  }
  return recipient;
}

export function buildObjectKey(recipient, receivedAt, objectId) {
  const normalized = normalizeRecipient(recipient);
  const timestamp = receivedAt.toISOString();
  const date = timestamp.slice(0, 10);
  return `${OBJECT_PREFIX}/${encodeURIComponent(normalized)}/${date}/${timestamp}-${objectId}.eml`;
}

export async function storeMessage(message, env, options = {}) {
  if (!env?.MAIL_BUCKET?.put) {
    throw new Error("MAIL_BUCKET R2 binding is required");
  }

  const receivedAt = options.receivedAt ?? new Date();
  const objectId = options.objectId ?? crypto.randomUUID();
  const envelopeTo = normalizeRecipient(message.to);
  const raw = await new Response(message.raw).arrayBuffer();
  const key = buildObjectKey(envelopeTo, receivedAt, objectId);

  await env.MAIL_BUCKET.put(key, raw, {
    httpMetadata: {
      contentType: "message/rfc822",
    },
    customMetadata: {
      envelopeFrom: truncateUtf8(message.from, 320),
      envelopeTo,
      receivedAt: receivedAt.toISOString(),
      rawSize: String(Number.isFinite(message.rawSize) ? message.rawSize : raw.byteLength),
      subject: truncateUtf8(message.headers?.get?.("subject"), SUBJECT_METADATA_BYTES),
      messageId: truncateUtf8(message.headers?.get?.("message-id"), MESSAGE_ID_METADATA_BYTES),
    },
  });

  return key;
}

export default {
  async email(message, env) {
    await storeMessage(message, env);
  },
};
