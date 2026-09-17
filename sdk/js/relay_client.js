/**
 * Sovereign Soul Engine — Relay Client (zero-dependency)
 *
 * A minimal Phoenix Channels v2 client for the Soul Society relay
 * (`/sse/socket`), plus the sovereign-identity primitives it needs:
 *
 *   - Ed25519 keypair generation (Node crypto / WebCrypto-compatible)
 *   - `did:soul:z<base58btc>` DIDs
 *   - JCS key-sorted canonical JSON for signing
 *   - Base58BTC signature encoding
 *   - Phoenix v2 wire protocol (`[join_ref, ref, topic, event, payload]`)
 *
 * Uses only native Node APIs (no npm dependencies). In a browser, replace the
 * `crypto` module with `globalThis.crypto.subtle` (WebCrypto) — the wire format
 * is identical.
 */

"use strict";

const crypto = require("crypto");

// ─────────────────────────────────────────────────────────────────────────────
// Base58BTC (Bitcoin alphabet)
// ─────────────────────────────────────────────────────────────────────────────

const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

function base58Encode(buffer) {
  const bytes = Array.from(buffer);

  let zeros = 0;
  while (zeros < bytes.length && bytes[zeros] === 0) zeros++;

  const digits = [];
  for (const byte of bytes) {
    let carry = byte;
    for (let i = 0; i < digits.length; i++) {
      carry += digits[i] * 256;
      digits[i] = carry % 58;
      carry = Math.floor(carry / 58);
    }
    while (carry > 0) {
      digits.push(carry % 58);
      carry = Math.floor(carry / 58);
    }
  }

  let out = "1".repeat(zeros);
  for (let i = digits.length - 1; i >= 0; i--) out += BASE58_ALPHABET[digits[i]];
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// JCS canonical JSON (RFC 8785-style key sorting; float formatting is a SHOULD)
// ─────────────────────────────────────────────────────────────────────────────

function jcs(value) {
  if (value === null || value === undefined) return "null";

  const t = typeof value;
  if (t === "boolean") return value ? "true" : "false";
  if (t === "number") return numberToJcs(value);
  if (t === "string") return JSON.stringify(value);

  if (Array.isArray(value)) {
    return "[" + value.map(jcs).join(",") + "]";
  }

  if (t === "object") {
    const keys = Object.keys(value).sort();
    return "{" + keys.map((k) => JSON.stringify(k) + ":" + jcs(value[k])).join(",") + "}";
  }

  throw new Error("JCS: unsupported type " + t);
}

function numberToJcs(n) {
  if (!Number.isFinite(n)) throw new Error("JCS: non-finite number " + n);
  if (Number.isInteger(n)) return String(n);
  return JSON.stringify(n);
}

// ─────────────────────────────────────────────────────────────────────────────
// Sovereign identity: Ed25519 + DID
// ─────────────────────────────────────────────────────────────────────────────

function generateKeypair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync("ed25519");
  return { publicKey, privateKey };
}

function rawPublicKey(publicKey) {
  const jwk = publicKey.export({ format: "jwk" });
  return Buffer.from(jwk.x, "base64url");
}

function didFromPublicKey(publicKey) {
  return "did:soul:z" + base58Encode(rawPublicKey(publicKey));
}

function signMessage(message, privateKey) {
  return crypto.sign(null, Buffer.from(message, "utf8"), privateKey);
}

function verifyMessage(message, signature, publicKey) {
  return crypto.verify(null, Buffer.from(message, "utf8"), publicKey, signature);
}

// ─────────────────────────────────────────────────────────────────────────────
// Signed relay envelope (RFC-0002 §4)
// ─────────────────────────────────────────────────────────────────────────────

const SIGNING_KEYS = ["v", "type", "from", "to", "id", "ts", "nonce", "prev", "payload"];

function buildEnvelope({ from, type, to = null, payload = {}, prev = null, nonce, id, ts }) {
  return {
    v: 1,
    type,
    from,
    to,
    id: id ?? crypto.randomUUID(),
    ts: ts ?? new Date().toISOString(),
    nonce: nonce ?? crypto.randomUUID(),
    prev,
    payload
  };
}

function signingFields(envelope) {
  const out = {};
  for (const k of SIGNING_KEYS) out[k] = envelope[k] ?? null;
  return out;
}

function signEnvelope(envelope, privateKey) {
  const signature = signMessage(jcs(signingFields(envelope)), privateKey);
  return { ...envelope, sig: base58Encode(signature) };
}

function verifyEnvelope(envelope, publicKey) {
  const signature = Buffer.from(base58Decode(envelope.sig));
  return verifyMessage(jcs(signingFields(envelope)), signature, publicKey);
}

function base58Decode(str) {
  const bytes = [];
  for (const ch of str) {
    let carry = BASE58_ALPHABET.indexOf(ch);
    if (carry < 0) throw new Error("base58: invalid character " + ch);
    for (let i = 0; i < bytes.length; i++) {
      carry += bytes[i] * 58;
      bytes[i] = carry & 0xff;
      carry >>= 8;
    }
    while (carry > 0) {
      bytes.push(carry & 0xff);
      carry >>= 8;
    }
  }
  let zeros = 0;
  while (zeros < str.length && str[zeros] === "1") zeros++;
  const body = Buffer.from(bytes.reverse());
  return Buffer.concat([Buffer.alloc(zeros), body]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Phoenix Channels v2 client
// ─────────────────────────────────────────────────────────────────────────────

class SoulRelayClient {
  constructor(url) {
    this.url = url;
    this.ws = null;
    this.ref = 0;
    this.pending = new Map(); // ref -> {resolve, reject}
    this.joinRefs = new Map(); // topic -> join ref
    this.pushHandler = null;
    this.heartbeatTimer = null;
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);

      this.ws.onopen = () => resolve();
      this.ws.onerror = () => reject(new Error("WebSocket failed to connect to " + this.url));
      this.ws.onclose = (event) => {
        this._rejectAll(new Error("WebSocket closed: " + event.code + " " + event.reason));
      };
      this.ws.onmessage = (event) => this._handleMessage(event.data);
    });
  }

  close() {
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
    if (this.ws) this.ws.close();
  }

  onPush(handler) {
    this.pushHandler = handler;
  }

  /** Resolves with the server push payload, or rejects on timeout. */
  waitForPush(topic, event, timeoutMs = 5000) {
    const client = this;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        client.pushHandler = previous;
        reject(new Error("timeout waiting for push " + topic + ":" + event));
      }, timeoutMs);

      const previous = client.pushHandler;
      const handler = (msg) => {
        if (msg.topic === topic && msg.event === event) {
          clearTimeout(timer);
          client.pushHandler = previous;
          resolve(msg.payload);
        }
      };
      client.pushHandler = (msg) => {
        if (previous) previous(msg);
        handler(msg);
      };
    });
  }

  async join(topic, payload = {}) {
    const ref = this.nextRef();
    const reply = await this._push(topic, "phx_join", payload, null, ref);
    this.joinRefs.set(topic, ref);
    return reply;
  }

  push(topic, event, payload) {
    const ref = this.nextRef();
    const joinRef = this.joinRefs.get(topic) || null;
    return this._push(topic, event, payload, joinRef, ref);
  }

  startHeartbeat(intervalMs = 25000) {
    this.heartbeatTimer = setInterval(() => {
      const ref = this.nextRef();
      try {
        this.ws.send(JSON.stringify([null, ref, "phoenix", "heartbeat", {}]));
      } catch (_e) {
        /* socket closing */
      }
    }, intervalMs);
  }

  _push(topic, event, payload, joinRef, ref) {
    return new Promise((resolve, reject) => {
      this.pending.set(ref, { resolve, reject });
      this.ws.send(JSON.stringify([joinRef, ref, topic, event, payload]));
    });
  }

  _handleMessage(raw) {
    const [joinRef, ref, topic, event, payload] = JSON.parse(raw);

    if (event === "phx_reply") {
      const entry = this.pending.get(ref);
      if (!entry) return;
      this.pending.delete(ref);

      if (payload.status === "ok") {
        entry.resolve(payload.response);
      } else {
        entry.reject(new Error(payload.status + ": " + JSON.stringify(payload.response)));
      }
      return;
    }

    if (event === "heartbeat") {
      // echo heartbeat replies
      return;
    }

    if (this.pushHandler) {
      this.pushHandler({ joinRef, ref, topic, event, payload });
    }
  }

  _rejectAll(error) {
    for (const entry of this.pending.values()) entry.reject(error);
    this.pending.clear();
  }

  nextRef() {
    return ++this.ref;
  }
}

module.exports = {
  SoulRelayClient,
  generateKeypair,
  rawPublicKey,
  didFromPublicKey,
  buildEnvelope,
  signEnvelope,
  verifyEnvelope,
  base58Encode,
  base58Decode,
  jcs,
  signMessage,
  verifyMessage
};
