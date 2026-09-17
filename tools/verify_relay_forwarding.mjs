/**
 * Cross-node relay forwarding verifier.
 *
 * Connects Soul A to one relay instance and Soul B to a *different* relay
 * instance, then proves A's direct envelope reaches B via peer forwarding —
 * the live "two machines meet over the wire" path.
 *
 *   node tools/verify_relay_forwarding.mjs
 *
 * Env:
 *   SSE_URL_A  (default ws://localhost:8562/sse/socket/websocket?vsn=2.0.0)
 *   SSE_URL_B  (default ws://localhost:8563/sse/socket/websocket?vsn=2.0.0)
 */

import relay from "../sdk/js/relay_client.js";

const { SoulRelayClient, generateKeypair, didFromPublicKey, buildEnvelope, signEnvelope } = relay;

const URL_A = process.env.SSE_URL_A || "ws://localhost:8562/sse/socket/websocket?vsn=2.0.0";
const URL_B = process.env.SSE_URL_B || "ws://localhost:8563/sse/socket/websocket?vsn=2.0.0";

async function main() {
  const A = generateKeypair();
  const B = generateKeypair();
  const didA = didFromPublicKey(A.publicKey);
  const didB = didFromPublicKey(B.publicKey);

  const clientA = new SoulRelayClient(URL_A);
  const clientB = new SoulRelayClient(URL_B);

  await clientA.connect();
  await clientB.connect();
  console.log("A connected -> " + URL_A);
  console.log("B connected -> " + URL_B);

  await clientA.join("world:sovereign-society", { did: didA });
  await clientB.join("soul:" + didB, { did: didB });

  const envelope = signEnvelope(
    buildEnvelope({ from: didA, type: "gossip", to: didB, payload: { secret: "cross-node" } }),
    A.privateKey
  );

  const bPush = clientB.waitForPush("soul:" + didB, "envelope", 10_000);
  await clientA.push("world:sovereign-society", "envelope", envelope);
  const received = await bPush;

  if (received.from === didA && received.to === didB && received.sig === envelope.sig) {
    console.log("\nCROSS-NODE FORWARDING VERIFIED");
    console.log("  A (node 1) --envelope--> relay forward --> B (node 2)");
    console.log("  B received signed envelope from " + received.from + " to " + received.to);
    process.exit(0);
  } else {
    console.error("FORWARDING FAILED: B did not receive A's envelope");
    process.exit(1);
  }
}

main().catch((e) => {
  console.error("fatal: " + (e && e.message));
  process.exit(1);
});
