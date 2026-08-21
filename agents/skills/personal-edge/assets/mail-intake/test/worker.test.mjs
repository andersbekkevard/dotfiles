import assert from "node:assert/strict";
import test from "node:test";

import {
  IntakeRejection,
  authorizeMessage,
  buildObjectKey,
  handleEmail,
  normalizeRecipient,
  storeMessage,
  trustedCloudflareAuthentication,
} from "../src/worker.mjs";

const DEFAULT_RAW = new TextEncoder().encode("Subject: Quarterly report\r\n\r\nhello");

function trustedAuthentication(domain = "example.com") {
  return `mx.cloudflare.net; dkim=pass header.d=${domain}; dmarc=pass (p=NONE) header.from=${domain}; spf=pass smtp.mailfrom=sender@${domain}`;
}

function message(overrides = {}) {
  const headers = new Headers({
    "authentication-results": trustedAuthentication(),
    from: "Quarterly Sender <sender@example.com>",
    subject: "Quarterly report",
    "message-id": "<report@example.com>",
  });
  const rejections = [];
  return {
    from: "sender@example.com",
    to: "Reports@bekkevard.me",
    headers,
    raw: new Response(DEFAULT_RAW).body,
    rawSize: DEFAULT_RAW.byteLength,
    rejections,
    setReject(reason) {
      rejections.push(reason);
    },
    ...overrides,
  };
}

function recordingBucket() {
  const writes = [];
  return {
    writes,
    async put(key, raw, options) {
      writes.push({ key, raw: new Uint8Array(raw), options });
    },
  };
}

function environment(overrides = {}) {
  return {
    MAIL_BUCKET: recordingBucket(),
    TRUSTED_SENDERS_JSON: JSON.stringify(["sender@example.com"]),
    MAX_RAW_BYTES: String(10 * 1024 * 1024),
    ...overrides,
  };
}

async function rejectionCode(mail, env = environment()) {
  const result = await handleEmail(mail, env);
  assert.equal(result.accepted, false);
  assert.equal(env.MAIL_BUCKET.writes.length, 0);
  assert.equal(mail.rejections.length, 1);
  return result.code;
}

test("stores exact raw bytes with authenticated envelope metadata", async () => {
  const raw = new Uint8Array([0, 13, 10, 255]);
  const env = environment();
  const key = await storeMessage(
    message({ raw: new Response(raw).body, rawSize: raw.byteLength }),
    env,
    {
      receivedAt: new Date("2026-07-10T12:34:56.789Z"),
      objectId: "fixed-id",
    },
  );

  assert.equal(
    key,
    "incoming/v1/reports%40bekkevard.me/2026-07-10/2026-07-10T12:34:56.789Z-fixed-id.eml",
  );
  assert.deepEqual(env.MAIL_BUCKET.writes[0].raw, raw);
  assert.equal(env.MAIL_BUCKET.writes[0].options.httpMetadata.contentType, "message/rfc822");
  assert.deepEqual(env.MAIL_BUCKET.writes[0].options.customMetadata, {
    authorFrom: "sender@example.com",
    envelopeFrom: "sender@example.com",
    envelopeTo: "reports@bekkevard.me",
    receivedAt: "2026-07-10T12:34:56.789Z",
    rawSize: "4",
    subject: "Quarterly report",
    messageId: "<report@example.com>",
  });
});

test("accepts unfolded Cloudflare authentication syntax", () => {
  const unfolded = "mx.cloudflare.net; dkim=pass header.d=example.com; dmarc=pass header.from=example.com policy.dmarc=none; spf=pass smtp.mailfrom=sender@example.com";
  const headers = { get: (name) => name.toLowerCase() === "authentication-results" ? unfolded : null };
  assert.deepEqual(trustedCloudflareAuthentication(headers), {
    headerFromDomain: "example.com",
  });
});

test("does not call Cloudflare's Set-Cookie-only Headers.getAll", () => {
  const mail = message();
  const get = mail.headers.get.bind(mail.headers);
  mail.headers = {
    get,
    getAll() {
      throw new TypeError('getAll() can only be used with the header name "Set-Cookie".');
    },
  };
  assert.equal(authorizeMessage(mail, environment()).authorFrom, "sender@example.com");
});

test("ignores other authserv ids but rejects a forged duplicate Cloudflare result", async () => {
  const other = message();
  other.headers.append("authentication-results", "other.example; dmarc=pass header.from=example.com");
  assert.equal(authorizeMessage(other, environment()).envelopeFrom, "sender@example.com");

  const duplicate = message();
  duplicate.headers.append(
    "authentication-results",
    "mx.cloudflare.net; dmarc=pass header.from=example.com",
  );
  assert.equal(await rejectionCode(duplicate), "cloudflare-authentication-ambiguous");
});

test("rejects unknown senders before reading raw bytes", async () => {
  let rawReads = 0;
  const mail = message();
  mail.headers.set("from", "attacker@example.com");
  Object.defineProperty(mail, "raw", {
    get() {
      rawReads += 1;
      return new Response(DEFAULT_RAW).body;
    },
  });
  assert.equal(await rejectionCode(mail), "sender-not-trusted");
  assert.equal(rawReads, 0);
});

test("rejects missing, failed, and misaligned DMARC before storage", async () => {
  const missing = message();
  missing.headers.delete("authentication-results");
  assert.equal(await rejectionCode(missing), "cloudflare-authentication-ambiguous");

  const failed = message();
  failed.headers.set(
    "authentication-results",
    "mx.cloudflare.net; dmarc=fail header.from=example.com",
  );
  assert.equal(await rejectionCode(failed), "dmarc-not-passed");

  const misaligned = message();
  misaligned.headers.set("authentication-results", trustedAuthentication("other.example"));
  assert.equal(await rejectionCode(misaligned), "dmarc-domain-misaligned");
});

test("accepts an exact trusted author when the provider envelope uses a bounce subdomain", async () => {
  const headers = new Headers({
    "authentication-results": "mx.cloudflare.net; dkim=pass header.d=bekkevard.me; dmarc=pass (p=NONE) header.from=bekkevard.me; spf=pass smtp.mailfrom=bounce@send.bekkevard.me",
    from: "Personal Edge <edge-test-sender@bekkevard.me>",
    subject: "Probe",
  });
  const env = environment({
    TRUSTED_SENDERS_JSON: JSON.stringify(["edge-test-sender@bekkevard.me"]),
  });
  const result = await handleEmail(
    message({ from: "bounce@send.bekkevard.me", headers }),
    env,
    { receivedAt: new Date("2026-07-10T00:00:00.000Z"), objectId: "probe" },
  );
  assert.equal(result.accepted, true);
  assert.equal(env.MAIL_BUCKET.writes[0].options.customMetadata.authorFrom, "edge-test-sender@bekkevard.me");
  assert.equal(env.MAIL_BUCKET.writes[0].options.customMetadata.envelopeFrom, "bounce@send.bekkevard.me");
});

test("rejects multiple or malformed author identities", async () => {
  for (const author of [
    "sender@example.com, attacker@example.com",
    "Sender <sender@example.com>, Attacker <attacker@example.com>",
    "not-an-address",
  ]) {
    const mail = message();
    mail.headers.set("from", author);
    assert.equal(await rejectionCode(mail), "author-from-ambiguous");
  }
});

test("rejects ambiguous DMARC and header.from results", async () => {
  const duplicateDmarc = message();
  duplicateDmarc.headers.set(
    "authentication-results",
    "mx.cloudflare.net; dmarc=pass header.from=example.com; dmarc=pass header.from=example.com",
  );
  assert.equal(await rejectionCode(duplicateDmarc), "dmarc-not-passed");

  const duplicateFrom = message();
  duplicateFrom.headers.set(
    "authentication-results",
    "mx.cloudflare.net; dmarc=pass header.from=example.com header.from=example.com",
  );
  assert.equal(await rejectionCode(duplicateFrom), "dmarc-header-from-ambiguous");
});

test("denies closed when sender or size policy is absent or malformed", async () => {
  assert.equal(
    await rejectionCode(message(), environment({ TRUSTED_SENDERS_JSON: undefined })),
    "trusted-senders-unconfigured",
  );
  assert.equal(
    await rejectionCode(message(), environment({ TRUSTED_SENDERS_JSON: "not-json" })),
    "trusted-senders-malformed",
  );
  assert.equal(
    await rejectionCode(message(), environment({ TRUSTED_SENDERS_JSON: '["sender@example.com",42]' })),
    "trusted-senders-malformed",
  );
  assert.equal(
    await rejectionCode(message(), environment({ TRUSTED_SENDERS_JSON: '["sender@example.com","SENDER@example.com"]' })),
    "trusted-senders-malformed",
  );
  for (const maximum of [undefined, "", "0", "1.5", String(25 * 1024 * 1024)]) {
    assert.equal(
      await rejectionCode(message(), environment({ MAX_RAW_BYTES: maximum })),
      "max-raw-bytes-malformed",
    );
  }
});

test("rejects oversized and invalid declared sizes before reading raw bytes", async () => {
  for (const rawSize of [Number.NaN, -1, 101]) {
    let rawReads = 0;
    const mail = message({ rawSize });
    Object.defineProperty(mail, "raw", {
      get() {
        rawReads += 1;
        return new Response(DEFAULT_RAW).body;
      },
    });
    const code = await rejectionCode(mail, environment({ MAX_RAW_BYTES: "100" }));
    assert.equal(
      code,
      Number.isSafeInteger(rawSize) && rawSize >= 0 ? "message-too-large" : "raw-size-invalid",
    );
    assert.equal(rawReads, 0);
  }
});

test("rejects a body larger than its declared size before R2 storage", async () => {
  const env = environment({ MAX_RAW_BYTES: "3" });
  const mail = message({ raw: new Response(new Uint8Array([1, 2, 3, 4])).body, rawSize: 3 });
  assert.equal(await rejectionCode(mail, env), "message-too-large");
});

test("separates recipients into encoded prefixes", () => {
  const now = new Date("2026-07-10T00:00:00.000Z");
  const first = buildObjectKey("one@bekkevard.me", now, "a");
  const second = buildObjectKey("two@bekkevard.me", now, "b");
  assert.match(first, /^incoming\/v1\/one%40bekkevard\.me\//);
  assert.match(second, /^incoming\/v1\/two%40bekkevard\.me\//);
  assert.notEqual(first, second);
});

test("encodes path-like and unicode recipients", () => {
  const recipient = normalizeRecipient("  Å/../Job@bekkevard.me  ");
  const key = buildObjectKey(recipient, new Date("2026-07-10T00:00:00.000Z"), "id");
  const prefix = key.split("/").slice(0, 3).join("/");
  assert.equal(prefix, `incoming/v1/${encodeURIComponent("å/../job@bekkevard.me")}`);
  assert.doesNotMatch(prefix.slice("incoming/v1/".length), /\//);
});

test("bounds attacker-controlled metadata", async () => {
  const env = environment();
  const headers = new Headers({
    "authentication-results": trustedAuthentication(),
    from: "sender@example.com",
    subject: "å".repeat(2000),
    "message-id": "x".repeat(2000),
  });
  await storeMessage(message({ headers }), env, {
    receivedAt: new Date("2026-07-10T00:00:00.000Z"),
    objectId: "id",
  });

  const metadata = env.MAIL_BUCKET.writes[0].options.customMetadata;
  assert.ok(new TextEncoder().encode(metadata.subject).byteLength <= 512);
  assert.ok(new TextEncoder().encode(metadata.messageId).byteLength <= 256);
});

test("propagates R2 failures without converting them to permanent rejection", async () => {
  const failure = new Error("R2 unavailable");
  const mail = message();
  await assert.rejects(
    handleEmail(mail, environment({ MAIL_BUCKET: { put: async () => { throw failure; } } })),
    failure,
  );
  assert.deepEqual(mail.rejections, []);
});

test("uses object ids to avoid timestamp collisions", () => {
  const now = new Date("2026-07-10T00:00:00.000Z");
  assert.notEqual(
    buildObjectKey("mail@bekkevard.me", now, "first"),
    buildObjectKey("mail@bekkevard.me", now, "second"),
  );
});

test("exposes rejection failures when EmailMessage cannot set an SMTP rejection", async () => {
  const mail = message({ setReject: undefined });
  mail.headers.set("from", "attacker@example.com");
  await assert.rejects(handleEmail(mail, environment()), /EmailMessage\.setReject is required/);
});

test("storeMessage surfaces intake policy failures to direct callers", async () => {
  await assert.rejects(
    storeMessage(message(), environment({ TRUSTED_SENDERS_JSON: "[]" })),
    (error) => error instanceof IntakeRejection && error.code === "trusted-senders-malformed",
  );
});
