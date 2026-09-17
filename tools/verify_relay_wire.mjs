/**
 * Relay wire-boundary verifier.
 *
 * Runs OUTSIDE the BEAM/ExUnit test runner as a standalone Node process against
 * the live Bandit server (http://localhost:8561). It spawns two distinct
 * sovereign souls (neither exists in PostgreSQL) and proves six things across a
 * real TCP/WebSocket boundary:
 *
 *   1. Real TCP WebSocket handshake
 *   2. Presence joining & tracking
 *   3. Broadcast gossip accepted & verified
 *   4. Point-to-point direct routing (Soul A -> Soul B)
 *   5. Replay attack rejection (SeenSet over TCP)
 *   6. Tampered-signature rejection
 *
 * Run:
 *   node tools/verify_relay_wire.mjs
 */

import relay from "../sdk/js/relay_client.js";

const {
  SoulRelayClient,
  generateKeypair,
  didFromPublicKey,
  buildEnvelope,
  signEnvelope,
  verifyEnvelope
} = relay;

const URL = process.env.SSE_RELAY_URL || "ws://localhost:8561/sse/socket/websocket?vsn=2.0.0";

let failures = 0;

function ok(msg) {
  console.log("  \u2713 " + msg);
}

function fail(msg) {
  failures++;
  console.error("  \u2717 " + msg);
}

function assert(cond, msg) {
  if (cond) ok(msg);
  else fail(msg);
}

async function main() {
  console.log("Soul Society relay wire verifier");
  console.log("  target: " + URL + "\n");

  // ── Self-check: the Node crypto pipeline is internally consistent ─────────
  const self = generateKeypair();
  const selfDid = didFromPublicKey(self.publicKey);
  const selfEnv = signEnvelope(
    buildEnvelope({ from: selfDid, type: "gossip", payload: { probe: true } }),
    self.privateKey
  );
  assert(verifyEnvelope(selfEnv, self.publicKey), "local Ed25519 sign/verify round-trip");
  assert(selfDid.startsWith("did:soul:z"), "DID format did:soul:z<base58>");

  // ── Two distinct sovereign souls ───────────────────────────────────────────
  const A = generateKeypair();
  const B = generateKeypair();
  const didA = didFromPublicKey(A.publicKey);
  const didB = didFromPublicKey(B.publicKey);

  const clientA = new SoulRelayClient(URL);
  const clientB = new SoulRelayClient(URL);

  // 1. Real TCP WebSocket handshake
  await clientA.connect();
  await clientB.connect();
  ok("1. WebSocket TCP handshake (A and B connected)");

  // 2. Presence joining & tracking
  const presencePromise = clientA.waitForPush("world:sovereign-society", "presence_state");
  await clientA.join("world:sovereign-society", { did: didA });
  const presenceState = await presencePromise;
  assert(Object.keys(presenceState).includes(didA), "2. presence_state tracks didA on join");

  await clientB.join("soul:" + didB, { did: didB });
  ok("2b. B joined soul:" + didB);

  // 3. Broadcast gossip accepted & verified (A -> world)
  const gossip = signEnvelope(
    buildEnvelope({ from: didA, type: "gossip", payload: { rumor: "the square is restless" } }),
    A.privateKey
  );
  const echoPromise = clientA.waitForPush("world:sovereign-society", "envelope");
  await clientA.push("world:sovereign-society", "envelope", gossip);
  const echoed = await echoPromise;
  assert(echoed.from === didA && echoed.sig === gossip.sig, "3. broadcast gossip verified & echoed");

  // 4. Point-to-point direct routing (A -> B)
  const direct = signEnvelope(
    buildEnvelope({ from: didA, type: "gossip", to: didB, payload: { secret: "psst" } }),
    A.privateKey
  );
  const bPush = clientB.waitForPush("soul:" + didB, "envelope");
  await clientA.push("world:sovereign-society", "envelope", direct);
  const received = await bPush;
  assert(received.from === didA && received.to === didB, "4. direct A->B envelope delivered");

  // 5. Replay attack rejection
  const replayable = signEnvelope(buildEnvelope({ from: didA, type: "gossip", payload: {} }), A.privateKey);
  await clientA.push("world:sovereign-society", "envelope", replayable);
  let replayed = false;
  try {
    await clientA.push("world:sovereign-society", "envelope", replayable);
  } catch (e) {
    replayed = e.message.includes("replayed");
  }
  assert(replayed, "5. replay rejected with reason=replayed");

  // 6. Tampered signature rejection
  const tampered = signEnvelope(buildEnvelope({ from: didA, type: "gossip", payload: { n: 1 } }), A.privateKey);
  tampered.payload.n = 999;
  let rejected = false;
  try {
    await clientA.push("world:sovereign-society", "envelope", tampered);
  } catch (e) {
    rejected = e.message.includes("invalid_signature");
  }
  assert(rejected, "6. tampered payload rejected with reason=invalid_signature");

  clientA.close();
  clientB.close();

  console.log("");
  if (failures === 0) {
    console.log("ALL WIRE-BOUNDARY VERIFICATIONS PASSED");
    process.exit(0);
  } else {
    console.error(failures + " verification(s) FAILED");
    process.exit(1);
  }
}

main().catch((e) => {
  console.error("fatal: " + (e && e.message));
  process.exit(1);
});
