const OBJECT_PREFIX = "incoming/v1";
const SUBJECT_METADATA_BYTES = 512;
const MESSAGE_ID_METADATA_BYTES = 256;
const PROVIDER_MAX_RAW_BYTES = 25 * 1024 * 1024;
const CLOUDFLARE_AUTHSERV_ID = "mx.cloudflare.net";

export class IntakeRejection extends Error {
  constructor(code, publicReason) {
    super(code);
    this.name = "IntakeRejection";
    this.code = code;
    this.publicReason = publicReason;
  }
}

function reject(code, publicReason = "Message is not accepted by this address") {
  throw new IntakeRejection(code, publicReason);
}

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

function normalizeMailbox(value, label) {
  const mailbox = String(value ?? "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+$/.test(mailbox)) {
    reject("invalid-mailbox", `Mail intake received an invalid ${label}`);
  }
  return mailbox;
}

export function normalizeRecipient(value) {
  return normalizeMailbox(value, "envelope recipient");
}

function trustedSendersFromEnv(env) {
  if (typeof env?.TRUSTED_SENDERS_JSON !== "string") {
    reject("trusted-senders-unconfigured", "Mail intake policy is unavailable");
  }

  let configured;
  try {
    configured = JSON.parse(env.TRUSTED_SENDERS_JSON);
  } catch {
    reject("trusted-senders-malformed", "Mail intake policy is unavailable");
  }

  if (!Array.isArray(configured) || configured.length === 0) {
    reject("trusted-senders-malformed", "Mail intake policy is unavailable");
  }

  const normalized = configured.map((sender) => {
    if (typeof sender !== "string") {
      reject("trusted-senders-malformed", "Mail intake policy is unavailable");
    }
    return normalizeMailbox(sender, "trusted sender");
  });
  const unique = new Set(normalized);
  if (unique.size !== normalized.length) {
    reject("trusted-senders-malformed", "Mail intake policy is unavailable");
  }
  return unique;
}

function maxRawBytesFromEnv(env) {
  if (typeof env?.MAX_RAW_BYTES !== "string" || !/^\d+$/.test(env.MAX_RAW_BYTES)) {
    reject("max-raw-bytes-malformed", "Mail intake policy is unavailable");
  }
  const maximum = Number(env.MAX_RAW_BYTES);
  if (!Number.isSafeInteger(maximum) || maximum <= 0 || maximum >= PROVIDER_MAX_RAW_BYTES) {
    reject("max-raw-bytes-malformed", "Mail intake policy is unavailable");
  }
  return maximum;
}

function headerValues(headers, name) {
  if (!headers || typeof headers.get !== "function") {
    reject("headers-unavailable");
  }
  const value = headers.get(name);
  return value === null ? [] : [String(value)];
}

function exactAuthorMailbox(headers) {
  const values = headerValues(headers, "from");
  if (values.length !== 1) reject("author-from-ambiguous");
  const value = values[0].trim();
  const angleAddress = value.match(
    /^(?:(?:"(?:[^"\\]|\\.)*"|[^<>,]+)\s*)?<([^<>,\s]+@[^<>,\s]+)>$/,
  );
  const mailbox = angleAddress?.[1] ?? (/^[^<>,\s]+@[^<>,\s]+$/.test(value) ? value : null);
  if (mailbox === null) reject("author-from-ambiguous");
  return normalizeMailbox(mailbox, "author sender");
}

function authenticationResultSegments(headers) {
  return headerValues(headers, "authentication-results").flatMap((value) =>
    value
      .split(/,(?=\s*[a-z0-9.-]+\s*;)/i)
      .map((segment) => segment.trim())
      .filter(Boolean),
  );
}

export function trustedCloudflareAuthentication(headers) {
  const trusted = authenticationResultSegments(headers).filter((segment) =>
    new RegExp(`^${CLOUDFLARE_AUTHSERV_ID.replaceAll(".", "\\.")}\\s*;`, "i").test(segment),
  );
  if (trusted.length !== 1) {
    reject("cloudflare-authentication-ambiguous");
  }

  const result = trusted[0];
  const dmarcResults = [...result.matchAll(/(?:^|;)\s*dmarc\s*=\s*([a-z]+)/gi)];
  if (dmarcResults.length !== 1 || dmarcResults[0][1].toLowerCase() !== "pass") {
    reject("dmarc-not-passed");
  }

  const headerFromResults = [
    ...result.matchAll(/\bheader\.from\s*=\s*(?:"([a-z0-9.-]+)"|([a-z0-9.-]+))/gi),
  ];
  if (headerFromResults.length !== 1) {
    reject("dmarc-header-from-ambiguous");
  }

  return {
    headerFromDomain: (headerFromResults[0][1] ?? headerFromResults[0][2]).toLowerCase(),
  };
}

export function authorizeMessage(message, env) {
  const trustedSenders = trustedSendersFromEnv(env);
  const maxRawBytes = maxRawBytesFromEnv(env);
  const envelopeFrom = normalizeMailbox(message?.from, "envelope sender");
  const authorFrom = exactAuthorMailbox(message.headers);
  if (!trustedSenders.has(authorFrom)) {
    reject("sender-not-trusted");
  }

  if (!Number.isSafeInteger(message?.rawSize) || message.rawSize < 0) {
    reject("raw-size-invalid");
  }
  if (message.rawSize > maxRawBytes) {
    reject("message-too-large", "Message exceeds the configured intake size limit");
  }

  const { headerFromDomain } = trustedCloudflareAuthentication(message.headers);
  const senderDomain = authorFrom.slice(authorFrom.lastIndexOf("@") + 1);
  if (headerFromDomain !== senderDomain) {
    reject("dmarc-domain-misaligned");
  }

  return { authorFrom, envelopeFrom, maxRawBytes };
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

  const { authorFrom, envelopeFrom, maxRawBytes } = authorizeMessage(message, env);
  const receivedAt = options.receivedAt ?? new Date();
  const objectId = options.objectId ?? crypto.randomUUID();
  const envelopeTo = normalizeRecipient(message.to);
  const raw = await new Response(message.raw).arrayBuffer();
  if (raw.byteLength > maxRawBytes) {
    reject("message-too-large", "Message exceeds the configured intake size limit");
  }
  const key = buildObjectKey(envelopeTo, receivedAt, objectId);

  await env.MAIL_BUCKET.put(key, raw, {
    httpMetadata: {
      contentType: "message/rfc822",
    },
    customMetadata: {
      authorFrom: truncateUtf8(authorFrom, 320),
      envelopeFrom: truncateUtf8(envelopeFrom, 320),
      envelopeTo,
      receivedAt: receivedAt.toISOString(),
      rawSize: String(raw.byteLength),
      subject: truncateUtf8(message.headers?.get?.("subject"), SUBJECT_METADATA_BYTES),
      messageId: truncateUtf8(message.headers?.get?.("message-id"), MESSAGE_ID_METADATA_BYTES),
    },
  });

  return key;
}

export async function handleEmail(message, env, options = {}) {
  try {
    const key = await storeMessage(message, env, options);
    console.log("mail-intake accepted");
    return { accepted: true, key };
  } catch (error) {
    if (!(error instanceof IntakeRejection)) throw error;
    console.warn("mail-intake rejected", error.code);
    if (typeof message?.setReject !== "function") {
      throw new Error("EmailMessage.setReject is required to deny rejected intake");
    }
    message.setReject(error.publicReason);
    return { accepted: false, code: error.code };
  }
}

export default {
  async email(message, env) {
    await handleEmail(message, env);
  },
};
