import assert from "node:assert/strict";
import test from "node:test";

import {
  buildObjectKey,
  normalizeRecipient,
  storeMessage,
} from "../src/worker.mjs";

function message(overrides = {}) {
  const headers = new Headers({
    subject: "Quarterly report",
    "message-id": "<report@example.com>",
  });
  return {
    from: "sender@example.com",
    to: "Reports@bekkevard.me",
    headers,
    raw: new Response("Subject: Quarterly report\r\n\r\nhello").body,
    rawSize: 42,
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

test("stores exact raw bytes with RFC822 metadata", async () => {
  const raw = new Uint8Array([0, 13, 10, 255]);
  const bucket = recordingBucket();
  const key = await storeMessage(
    message({ raw: new Response(raw).body, rawSize: raw.byteLength }),
    { MAIL_BUCKET: bucket },
    {
      receivedAt: new Date("2026-07-10T12:34:56.789Z"),
      objectId: "fixed-id",
    },
  );

  assert.equal(
    key,
    "incoming/v1/reports%40bekkevard.me/2026-07-10/2026-07-10T12:34:56.789Z-fixed-id.eml",
  );
  assert.deepEqual(bucket.writes[0].raw, raw);
  assert.equal(bucket.writes[0].options.httpMetadata.contentType, "message/rfc822");
  assert.equal(bucket.writes[0].options.customMetadata.envelopeTo, "reports@bekkevard.me");
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
  const bucket = recordingBucket();
  const headers = new Headers({
    subject: "å".repeat(2000),
    "message-id": "x".repeat(2000),
  });
  await storeMessage(message({ headers }), { MAIL_BUCKET: bucket }, {
    receivedAt: new Date("2026-07-10T00:00:00.000Z"),
    objectId: "id",
  });

  const metadata = bucket.writes[0].options.customMetadata;
  assert.ok(new TextEncoder().encode(metadata.subject).byteLength <= 512);
  assert.ok(new TextEncoder().encode(metadata.messageId).byteLength <= 256);
});

test("propagates R2 failures", async () => {
  const failure = new Error("R2 unavailable");
  await assert.rejects(
    storeMessage(message(), { MAIL_BUCKET: { put: async () => { throw failure; } } }, {
      receivedAt: new Date("2026-07-10T00:00:00.000Z"),
      objectId: "id",
    }),
    failure,
  );
});

test("uses object ids to avoid timestamp collisions", () => {
  const now = new Date("2026-07-10T00:00:00.000Z");
  assert.notEqual(
    buildObjectKey("mail@bekkevard.me", now, "first"),
    buildObjectKey("mail@bekkevard.me", now, "second"),
  );
});
