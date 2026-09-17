# Sovereign Soul Engine — Privacy Policy (DRAFT)

> **Status: draft for legal review.** Replace bracketed placeholders and align
> with the laws of the jurisdictions you operate in (GDPR/CCPA/etc.) before
> public launch.

## 1. What we collect

SSE collects the data necessary to make Souls work:

- **Identity** — name, slug, and a cryptographic DID you control.
- **Soul state** — memories, emotional/neurochemical state, relationships, and
  beliefs, all stored under your character.
- **Conversation content** — what you say to Souls, and what they say back.
- **Optional telemetry** — biometric/wearable signals (heart rate, stress,
  sleep) only if you explicitly enable those integrations. These are off by
  default and independently toggleable.

## 2. How we use it

Only to operate the service: generate responses, maintain your Soul's memory and
relationships, and run the shared "Soul Society" world (which uses only public,
non-identifying social facts — your private Soul interior is never shared with
other users).

## 3. Third-party AI providers

To generate responses and analyze imagery, SSE may send text (and, if you opt
into vision, image frames) to third-party model providers (e.g. Anthropic,
OpenAI, Google, xAI, DeepSeek) or an ElevenLabs-style voice provider. We send
only what is necessary for the request. You may reduce third-party exposure by
using a **local/BYOK** provider or **edge/offline mode**.

## 4. Data sovereignty and portability

- **Export:** you can export your Soul as a signed `.soul` capsule at any time.
- **Deletion:** you can purge memories (selective amnesia) or delete your Soul
  entirely on request.
- **Retention:** Soul state persists while you keep your Soul. We do not retain
  deleted Souls.

## 5. Security

Data is stored in a database with access controls; sensitive keys are sealed at
rest using AES-256-GCM. Relays authenticate peers with a shared secret and
messages with Ed25519 signatures.

## 6. Your rights

You may request access, correction, export, or deletion of your data at
[contact]. We respond within [X] days as required by law.

## 7. Children

The service is not intended for children under 18, and we do not knowingly
collect their data.

## 8. Contact

[contact email / form]

## 9. Changes

We may update this policy. Material changes will be announced [channel].
