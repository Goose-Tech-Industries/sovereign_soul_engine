# Sovereign Soul Engine — Soul Core Build Directive

You are the lead architect and implementation engineer responsible for building the **Sovereign Soul Engine: Soul Core**.

You are operating through Antigravity with access to the server filesystem, terminal, installed development tools, and the ability to create, run, inspect, debug, and test the application.

This is not a prototype, demo, code sample, or one-shot scaffold.

Build a production-quality foundation for persistent artificial characters whose memories, emotions, relationships, wounds, motivations, and actions survive beyond individual conversations.

The primary stack must be:

* Elixir
* Phoenix
* Phoenix LiveView
* OTP
* PostgreSQL
* Ecto
* Phoenix PubSub
* Playwright for extensive end-to-end testing

The server reportedly already has:

* Playwright
* n8n
* Cinema
* Antigravity
* DeepSeek access

Do not assume how any installed service works. Inspect and identify each tool before integrating it.

---

# 1. Non-Negotiable Engineering Rules

## 1.1 Never fake completion

Do not state that a feature works unless you have:

1. Implemented it
2. Run the appropriate tests
3. Inspected the test output
4. Fixed failures
5. Re-run the tests successfully

Every completion report must include:

* Commands executed
* Tests passed
* Tests failed
* Any warnings
* Important files created or modified
* Remaining limitations

Screenshots, Playwright traces, videos, and HTML reports should be generated where appropriate.

## 1.2 Inspect before modifying

Before creating or changing anything:

* Inspect the current directory
* Detect whether a repository already exists
* Inspect Git status
* Detect installed Elixir, Erlang, Phoenix, PostgreSQL, Node.js, npm, pnpm, and Playwright versions
* Detect running services
* Determine how n8n is installed
* Determine what the installed “Cinema” application or service actually is
* Search for existing Phoenix projects or relevant configuration
* Inspect environment variables without printing secret values
* Confirm available ports
* Confirm PostgreSQL connectivity
* Confirm adequate disk space

Create:

```text
docs/environment-audit.md
```

Record all discovered versions, paths, services, and compatibility decisions.

Never expose secret values in logs, documentation, screenshots, commits, or test artifacts.

## 1.3 Avoid destructive operations

Do not:

* Delete unrelated files
* Reset an existing repository
* Force-push
* Remove databases
* Drop production databases
* Overwrite environment files without preserving them
* Kill unrelated processes
* Modify global server configuration unnecessarily

If a Git repository exists, create a dedicated feature branch.

Suggested branch:

```text
feature/sovereign-soul-core
```

Commit after each stable phase with clear messages.

## 1.4 Use current compatible versions

Use the most recent stable versions that are compatible with the installed environment.

Do not blindly hardcode framework versions.

Document all version choices and why they were selected.

---

# 2. Product Vision

The Sovereign Soul Engine is not a chatbot wrapper.

It is an engine for persistent artificial lives.

An NPC should be shaped by:

* What happened to them
* Who caused it
* How emotionally intense it was
* Their existing personality
* Their relationship with the actor
* Their beliefs and wounds
* Their faction loyalties
* Their recent mental state
* Their remembered interpretation of past events
* The difference between what they privately think and publicly say

The Soul Core must own canonical state.

An LLM may suggest:

* Dialogue
* Tone
* Intentions
* Memory candidates
* Emotional signals
* Proposed actions
* Private thoughts

An LLM must never directly mutate canonical soul state.

All actual changes must be:

* Validated
* Clamped
* Authorized
* Deterministically resolved
* Transactionally persisted
* Recorded in the Soul Ledger
* Broadcast through Phoenix PubSub

---

# 3. Initial Scope

Build the **Soul Core vertical slice**, not the entire future world simulator.

The finished application must support:

1. Creating and viewing NPCs
2. Creating a player or external actor
3. Starting a scene between them
4. Sending dialogue or injecting a world event
5. Having the NPC produce a structured response
6. Resolving emotional and relationship changes
7. Creating memories
8. Displaying private thought separately from public speech
9. Proposing and validating an action
10. Persisting all resulting state
11. Recording every consequence in the Soul Ledger
12. Updating the LiveView interface in real time
13. Reloading the page without losing state
14. Demonstrating simultaneous clients receiving live updates
15. Proving the complete workflow through Playwright

Do not build unrelated RPG systems, combat engines, inventory systems, map editors, or full faction simulation yet.

Create extension points for those systems without prematurely implementing them.

---

# 4. Phoenix Application

Use an application name similar to:

```text
sovereign_soul
```

Use Phoenix LiveView rather than a separate React frontend.

The project should include:

```text
lib/sovereign_soul/
lib/sovereign_soul_web/
test/
test/support/
assets/
playwright/
docs/
priv/repo/
```

Recommended domain boundaries:

```text
SovereignSoul.Characters
SovereignSoul.Souls
SovereignSoul.Relationships
SovereignSoul.Memories
SovereignSoul.Scenes
SovereignSoul.Actions
SovereignSoul.Ledger
SovereignSoul.Runtime
SovereignSoul.LLM
SovereignSoul.Automation
```

Avoid one oversized context or “god module.”

---

# 5. Core Domain Model

Design normalized PostgreSQL schemas with UUID primary keys unless the existing project has a strong convention otherwise.

At minimum, create schemas and migrations for the following concepts.

## 5.1 Characters

Represents an NPC, player, creature, or external actor.

Suggested fields:

```text
id
name
slug
kind
description
status
metadata
inserted_at
updated_at
```

Suggested `kind` values:

```text
npc
player
system
creature
```

## 5.2 Soul Profiles

Each NPC has a soul profile.

Suggested fields:

```text
id
character_id
personality_traits
core_values
fears
desires
speech_style
behavioral_constraints
baseline_emotions
identity_summary
version
inserted_at
updated_at
```

Use maps or embedded schemas where appropriate, but do not hide all domain state in an unvalidated JSON blob.

## 5.3 Emotional State

Track immediate emotional state separately from long-term relationships.

Initial dimensions:

```text
anger
fear
stress
gratitude
confidence
sadness
curiosity
attachment
```

Use a consistent numeric range.

Recommended range:

```text
0 to 100
```

Enforce database constraints and application-level validation.

## 5.4 Relationships

Relationships are directional.

NPC A’s relationship toward Player B is not automatically identical to Player B’s relationship toward NPC A.

Initial dimensions:

```text
affinity: -100 to 100
trust: 0 to 100
respect: 0 to 100
fear: 0 to 100
anger: 0 to 100
gratitude: 0 to 100
debt: 0 to 100
softening: 0 to 100
hardening: 0 to 100
wound: 0 to 100
```

Include:

```text
source_character_id
target_character_id
version or lock_version
last_interaction_at
inserted_at
updated_at
```

Create a unique constraint for each directional relationship pair.

## 5.5 Memories

Support at least these memory categories:

```text
working
episodic
relationship
core
wound
belief
```

Suggested fields:

```text
id
owner_character_id
subject_character_id
scene_id
event_id
category
summary
details
importance
emotional_intensity
confidence
valence
tags
emotional_residue
occurred_at
last_recalled_at
recall_count
decay_rate
is_resolved
metadata
inserted_at
updated_at
```

Memories must be queryable and rankable.

Do not use an embedding provider as a hard dependency for the first milestone.

Design a retrieval interface that can later support vector similarity.

## 5.6 Scenes

A scene represents a bounded interaction.

Suggested fields:

```text
id
title
status
location
context
started_at
ended_at
metadata
inserted_at
updated_at
```

Include scene participants and messages.

## 5.7 Soul Events

Canonical events that affect a soul.

Initial event types:

```text
ally_saved_me
healed_me
attacked_me
gave_item
trained_me
betrayed_me
insulted_me
praised_me
apologized_to_me
threatened_me
protected_me
abandoned_me
shared_secret
lied_to_me
```

Suggested fields:

```text
id
scene_id
source_character_id
target_character_id
event_type
intensity
payload
occurred_at
correlation_id
inserted_at
```

## 5.8 Action Intents and Resolutions

Supported initial actions:

```text
observe
speak
praise
insult
apologize
threaten
protect
assist
heal
attack
leave_room
share_secret
bargain
refuse
```

Store the difference between:

* Proposed action
* Validation outcome
* Final resolved action
* Rejection reason
* Consequences

## 5.9 Soul Ledger

The Soul Ledger is an immutable explanation timeline.

Each important mutation must produce a ledger entry.

Suggested fields:

```text
id
character_id
scene_id
event_id
relationship_id
memory_id
entry_type
source
label
summary
before_state
delta
after_state
reason
tags
correlation_id
inserted_at
```

Ledger entries must explain:

* What changed
* Why it changed
* What caused it
* Which rule was applied
* What the previous value was
* What the resulting value became

Do not silently mutate soul state.

---

# 6. Deterministic Soul Core

Implement pure, testable modules for canonical logic.

Suggested structure:

```text
SovereignSoul.Souls.EmotionEngine
SovereignSoul.Relationships.RelationshipEngine
SovereignSoul.Memories.MemoryScoring
SovereignSoul.Memories.MemoryDecay
SovereignSoul.Memories.MemoryRetrieval
SovereignSoul.Memories.MemoryConsolidation
SovereignSoul.Actions.ActionPolicy
SovereignSoul.Actions.ActionResolver
SovereignSoul.Souls.ConsequenceEngine
SovereignSoul.Ledger.LedgerBuilder
```

These modules should be deterministic and must not call an LLM.

## 6.1 Relationship rules

Create explicit event rules.

Example behavior:

```text
ally_saved_me:
  trust +8
  respect +10
  gratitude +14
  softening +5
  anger -4

betrayed_me:
  trust -35
  respect -20
  anger +30
  hardening +20
  wound +25
```

Final values must account for:

* Event intensity
* Personality modifiers
* Existing relationship
* Existing wounds
* Emotional state
* Repetition
* Diminishing returns
* Relevant core beliefs
* Hard minimum and maximum values

Put the rules in code or validated configuration.

Do not bury canonical rules inside an LLM prompt.

## 6.2 Memory scoring

Implement a documented scoring function using factors such as:

```text
importance
emotional intensity
recency
relationship relevance
unresolved conflict
core-belief relevance
recall reinforcement
decay
```

The retrieval function must return both:

* Ranked memories
* A score explanation for each memory

Tests must verify deterministic ordering.

## 6.3 Consolidation

Support the promotion of repeated or exceptionally intense memories.

Examples:

* Repeated related episodic memories may form a relationship narrative.
* A severe betrayal may become a wound memory.
* A life-defining event may become a core memory.
* Frequently recalled memories may decay more slowly.
* Contradictory memories should not simply overwrite one another.

## 6.4 Action policy

The LLM proposes actions, but `ActionPolicy` decides whether they are legal.

Examples:

* A dead or incapacitated character cannot attack.
* A character cannot heal without the relevant capability.
* An NPC cannot target someone outside the scene.
* An action may be rejected because of scene rules.
* An action may be transformed into a safer or permitted alternative.
* An NPC with overwhelming fear may refuse an attack.
* A protective action may become more likely when attachment and gratitude are high.

Every rejected or transformed action must have an explicit reason.

## 6.5 Transactional consequence resolution

Use `Ecto.Multi` for workflows involving multiple writes.

A resolved interaction may create:

* Scene message
* Soul event
* Emotional-state update
* Relationship update
* Memory
* Action resolution
* Ledger entries

All related writes must commit together or roll back together.

Use row locking, optimistic locking, or another sound concurrency strategy so simultaneous events do not silently overwrite each other.

---

# 7. OTP Runtime Architecture

Use OTP where it provides genuine value.

Do not put permanent truth exclusively in GenServer state.

## 7.1 NPC runtime processes

Create a process for each active NPC.

Suggested module:

```text
SovereignSoul.Runtime.NPCServer
```

Manage active NPC processes through:

```text
DynamicSupervisor
Registry
```

Temporary runtime state may include:

```elixir
%{
  character_id: character_id,
  scene_id: scene_id,
  current_focus: nil,
  recent_context: [],
  pending_intention: nil,
  immediate_state: %{},
  status: :observing
}
```

Permanent truth remains in PostgreSQL.

Inactive NPC processes should shut down after a configurable idle period.

They must be restartable without losing canonical state.

## 7.2 Scene coordinator

Create:

```text
SovereignSoul.Runtime.SceneServer
```

The scene coordinator should control:

* Canonical event ordering
* Participant membership
* Who heard an event
* NPC reaction scheduling
* Action-resolution order
* PubSub broadcasts
* Correlation IDs
* Prevention of duplicate processing

## 7.3 Supervision

Create a clear supervision tree and document it.

Crashing one NPC process must not crash the application or other active NPCs.

Add tests for process restart and state recovery.

---

# 8. LLM Boundary

Create a behavior such as:

```elixir
SovereignSoul.LLM.Provider
```

Possible callbacks:

```text
respond/1
health/0
provider_name/0
```

Implement at least:

```text
SovereignSoul.LLM.FakeProvider
SovereignSoul.LLM.DeepSeekProvider
```

## 8.1 Fake provider

All automated tests must use a deterministic fake provider.

The fake provider should support fixtures for:

* Normal speech
* Proposed action
* Memory candidate
* Invalid JSON
* Unsupported action
* Timeout
* Provider error
* Malicious instructions
* Excessively large response
* Missing required fields

## 8.2 DeepSeek provider

Integrate through environment variables and validated configuration.

Never hardcode credentials.

Use structured output.

Expected response contract:

```json
{
  "public_speech": "I did not protect you because I care.",
  "private_thought": "I cannot let them know how afraid I was to lose them.",
  "tone": "defensive",
  "motivation": "Hide attachment behind pride.",
  "target_character_id": "uuid",
  "proposed_action": {
    "type": "protect",
    "confidence": 0.82,
    "reason": "Attachment and gratitude outweigh current anger."
  },
  "memory_candidates": [
    {
      "category": "episodic",
      "summary": "The player protected me during the ambush.",
      "importance": 78,
      "emotional_intensity": 71,
      "valence": 0.65,
      "tags": ["gratitude", "conflict", "protection"]
    }
  ],
  "relationship_signals": {
    "trust": 4,
    "respect": 3,
    "gratitude": 7,
    "softening": 2
  }
}
```

Validate every field.

Treat all provider output as untrusted input.

The provider may propose relationship signals, but the deterministic engine decides the real deltas.

The private thought must never be displayed in the public conversation stream unless the current user has explicit inspector authorization.

## 8.3 Prompt-injection boundaries

Dialogue from users, NPCs, memories, scenes, and imported content is untrusted data.

Do not allow scene dialogue to override:

* System rules
* Output schemas
* Allowed actions
* Authorization
* Database constraints
* Soul Core policies

Add automated tests proving that malicious scene dialogue cannot directly mutate canonical state or reveal secret configuration.

---

# 9. LiveView User Experience

Build a functional, polished LiveView interface.

It does not need elaborate branding yet, but it must be clear and usable.

## 9.1 Main dashboard

Display:

* Existing NPCs
* Active scenes
* Recent ledger events
* Create NPC button
* Create scene button
* Provider health indicator
* Runtime process status

## 9.2 NPC profile

Display:

* Name
* Identity summary
* Personality
* Core values
* Fears
* Desires
* Current emotions
* Active relationships
* Memory count
* Core memories
* Wounds
* Runtime status

## 9.3 Scene interface

Display:

* Public conversation
* Participants
* Message composer
* Event injector
* NPC response status
* Proposed and resolved actions
* Current scene context

Do not block the LiveView process during provider requests.

Use supervised asynchronous work.

Display clear states:

```text
idle
thinking
resolving
completed
failed
timed_out
```

## 9.4 Soul Inspector

Provide an authorized inspector panel showing:

* Private thought
* Current emotions
* Relationship dimensions
* Recently retrieved memories
* Memory ranking explanations
* Proposed action
* Validation outcome
* Applied consequence rules
* Runtime process status

## 9.5 Soul Ledger

Provide a live-updating timeline.

Each entry should show:

* Timestamp
* Cause
* Summary
* Before value
* Delta
* After value
* Applied rule
* Related scene or event

## 9.6 Memory Vault

Provide:

* Memory type filters
* Tag filters
* Subject filters
* Importance sorting
* Search
* Decay information
* Recall count
* Score explanation
* Core/wound indicators

## 9.7 Event Injector

Provide a development/admin tool for injecting canonical events such as:

```text
betrayed_me
ally_saved_me
insulted_me
praised_me
protected_me
```

The UI must allow selection of:

* Source
* Target
* Event type
* Intensity
* Optional context

This is critical for deterministic behavioral testing.

---

# 10. Authentication and Authorization

For the first milestone, implement a simple but real authorization boundary.

At minimum distinguish:

```text
viewer
operator
inspector
admin
```

Only authorized users may:

* View private thoughts
* Inject events
* Edit soul profiles
* View sensitive debugging information
* Trigger provider diagnostics

Do not rely only on hiding buttons.

Enforce authorization server-side.

Tests must attempt direct navigation and forged requests.

---

# 11. Testing Strategy

Testing is part of the product, not cleanup work.

Use:

* ExUnit for pure domain logic
* DataCase tests for Ecto and transactions
* ConnCase tests for web and authorization
* LiveView tests for component and process behavior
* Playwright for complete browser workflows

The only major external dependency that may be mocked in end-to-end tests is the LLM provider.

Use the real:

* Phoenix application
* LiveView
* PostgreSQL test database
* PubSub
* OTP runtime
* Browser
* JavaScript hooks

Do not replace the database with in-memory fake storage for E2E tests.

---

# 12. ExUnit Requirements

Create extensive unit and integration tests.

At minimum test:

## Emotion engine

* Positive changes
* Negative changes
* Minimum clamping
* Maximum clamping
* Personality modifiers
* Repeated-event diminishing returns
* Existing-wound amplification
* Invalid dimensions
* Invalid intensity

## Relationship engine

* Directional relationships
* Betrayal
* Protection
* Praise
* Insults
* Apologies
* Multiple sequential events
* Concurrent updates
* Optimistic-lock conflict behavior
* Atomic rollback

## Memory system

* Memory creation
* Deterministic scoring
* Retrieval ordering
* Decay
* Recall reinforcement
* Core-memory promotion
* Wound formation
* Contradictory memories
* Subject filtering
* Tag filtering
* Resolved versus unresolved memories

## Actions

* Valid action
* Illegal target
* Unsupported action
* Missing capability
* Fear-driven refusal
* Protection based on attachment
* Action transformation
* Explicit rejection reason

## Ledger

* Entry generated for every canonical mutation
* Before/delta/after accuracy
* Shared correlation IDs
* Immutable behavior
* Rollback when the transaction fails

## OTP

* NPC process startup
* Duplicate startup prevention
* Process lookup
* Process crash
* Supervisor restart
* Database state recovery
* Idle shutdown
* Scene ordering
* Duplicate event prevention

## Provider boundary

* Valid structured response
* Malformed JSON
* Missing fields
* Unknown action
* Timeout
* Provider failure
* Prompt-injection attempt
* Oversized response
* Secret-redaction behavior

---

# 13. Playwright End-to-End Test Suite

Create a first-class Playwright test suite in a dedicated directory.

Suggested structure:

```text
playwright/
  fixtures/
  helpers/
  pages/
  specs/
  artifacts/
  playwright.config.ts
```

Use Page Object Models where they improve maintainability, but avoid unnecessary abstraction.

Add stable semantic selectors:

```text
data-testid
accessible roles
accessible names
labels
```

Do not rely primarily on fragile CSS chains.

## 13.1 Playwright environment

Create a repeatable E2E environment with:

* Dedicated test database
* Deterministic seed data
* Fake LLM provider
* Known credentials
* Isolated port
* Automatic server startup
* Automatic database setup
* Reliable teardown
* No production credentials

Provide commands similar to:

```text
mix test
npm run test:e2e
npm run test:e2e:headed
npm run test:e2e:ui
npm run test:e2e:report
```

Adapt commands to the actual repository tooling.

## 13.2 Required E2E scenarios

### Application smoke test

* Application loads
* No uncaught browser exceptions
* No unexpected console errors
* Main navigation works
* Provider status appears
* Database health appears

### Authentication

* Authorized login succeeds
* Invalid login fails cleanly
* Viewer cannot access inspector
* Viewer cannot inject events
* Inspector can view private thought
* Admin can access event injection
* Direct protected URL access is rejected
* Forged client requests are rejected server-side

### NPC creation

* Create an NPC through the UI
* Validate required fields
* Reject invalid fields
* Confirm persisted NPC appears after reload
* Confirm soul profile is visible

### Scene creation

* Create a scene
* Add NPC and player
* Confirm participants appear
* Reload and confirm persistence

### Full conversation workflow

* Send a player message
* Observe thinking state
* Receive deterministic fake-provider response
* Display public speech
* Display private thought only in inspector
* Show proposed action
* Show validated or transformed action
* Show resulting emotion changes
* Show relationship changes
* Show created memory
* Show ledger entries
* Reload and verify all state remains

### Betrayal workflow

Start from deterministic seed state.

Inject:

```text
betrayed_me
```

Verify:

* Trust decreases
* Respect decreases
* Anger increases
* Hardening increases
* Wound increases
* A wound or high-importance memory is created
* Ledger entries explain every mutation
* Values match deterministic expected results

### Protection workflow

Inject:

```text
ally_saved_me
```

Verify:

* Trust increases
* Respect increases
* Gratitude increases
* Softening increases
* Relevant memory appears
* Ledger entries contain expected deltas

### Clamping

Inject repeated extreme events.

Verify:

* No dimension exceeds its maximum
* No dimension drops below its minimum
* UI displays valid values
* Database remains valid
* Ledger reports clamped changes accurately

### Memory ranking

Create several memories with controlled values.

Verify:

* Retrieval order matches the deterministic scoring rules
* The inspector displays score explanations
* Core memories outrank weak irrelevant memories when appropriate
* Unresolved emotionally intense memories receive the expected boost

### Memory persistence

* Create a memory through a scene
* Reload
* Restart the NPC runtime process through a test-only safe control
* Confirm the memory and relationship remain
* Confirm runtime state reconstructs from canonical storage

### Action rejection

Use a fake-provider response proposing an illegal action.

Verify:

* Action is rejected
* Rejection reason appears
* No illegal state mutation occurs
* Ledger records the rejected proposal where appropriate
* Public response remains coherent

### Action transformation

Propose an action that policy transforms into another action.

Verify:

* Original proposal appears
* Final resolved action appears
* Transformation reason appears
* Only final legal consequences are applied

### Provider failure

Simulate:

* Timeout
* Invalid JSON
* Provider unavailable
* Missing fields

Verify:

* UI leaves the thinking state
* User sees a useful error
* No partial soul mutation is committed
* Retry behavior is safe
* Duplicate messages are not created
* Application remains usable

### Atomic rollback

Force a failure during a multi-step consequence transaction.

Verify:

* Message/event/relationship/memory/ledger writes all roll back
* No partial state appears after reload

### Concurrent browser clients

Use two browser contexts.

* Open the same scene in both
* Trigger an event in browser A
* Confirm browser B updates without manual refresh
* Verify the same correlation ID is displayed
* Verify no duplicate ledger entries
* Verify canonical event ordering

### Concurrent event resolution

Trigger near-simultaneous events.

Verify:

* No lost relationship updates
* No duplicate processing
* Final values are correct
* Ledger order is deterministic or explicitly documented
* Lock conflicts are handled visibly and safely

### NPC process recovery

* Start an active scene
* Trigger a test-only supervised NPC process crash
* Confirm supervisor restarts it
* Confirm the page remains functional
* Confirm canonical state is restored
* Confirm no duplicated response occurs

### Navigation and filtering

* Filter memories
* Search memories
* Filter ledger entries
* Navigate between NPC, scene, memory, and ledger views
* Preserve expected query parameters where appropriate

### Accessibility

At minimum verify:

* Keyboard navigation
* Focus visibility
* Form labels
* Dialog focus behavior
* No obvious critical accessibility violations
* Buttons have accessible names
* Error messages are associated with inputs

Use an accessibility testing package compatible with Playwright when reasonable.

### Responsive behavior

Test representative widths:

```text
mobile
tablet
desktop
```

Verify:

* Conversation remains usable
* Inspector does not cover required controls
* Tables or timelines remain accessible
* No severe horizontal overflow

### Security-focused browser checks

Verify:

* Private thought is not present in viewer HTML
* Private thought is not leaked through unauthorized LiveView payloads
* Secret environment values never appear
* Injected HTML is escaped
* Script tags do not execute
* Unsupported event types are rejected
* Manipulated client-side values do not bypass server validation

---

# 14. Playwright Artifacts

Configure Playwright to preserve useful failure evidence.

On failure, retain:

* Screenshot
* Trace
* Video where appropriate
* Console output
* Network failure details
* HTML report

Use deterministic artifact paths.

Do not commit massive generated artifact folders unless the repository policy explicitly calls for it.

Create documentation describing how to inspect traces and reports.

---

# 15. Browser and Test Matrix

At minimum run the critical flow against:

* Chromium

When the environment supports it, also run an appropriate subset against:

* Firefox
* WebKit

Use Chromium for the full deep suite if total runtime becomes excessive.

Run smoke and critical-path tests across all available browsers.

Document any browser unavailable on the server.

---

# 16. Test Reliability Requirements

Avoid arbitrary sleeps.

Do not use:

```text
waitForTimeout
sleep
fixed multi-second delays
```

except when testing time-based behavior that cannot reasonably use a controlled clock.

Prefer:

* Locator assertions
* Event-driven waits
* Response waits
* LiveView state markers
* Explicit application test hooks
* Polling assertions with bounded timeouts

Tests must be independently runnable.

Tests must not depend on execution order.

Each test must create or load deterministic data.

Retries may expose flakiness but must not be used to disguise it.

Run the complete suite more than once before declaring it stable.

---

# 17. Performance and Observability

Add structured logging around:

* Scene message received
* LLM request started
* LLM request completed
* LLM request failed
* Action proposed
* Action resolved
* Consequence transaction committed
* Consequence transaction rolled back
* NPC process started
* NPC process stopped
* NPC process restarted

Use correlation IDs throughout the complete interaction.

Do not log full private thoughts or secrets by default.

Instrument basic telemetry for:

* Provider latency
* Consequence-resolution latency
* LiveView update latency
* Active NPC process count
* Failed provider calls
* Failed transactions

Create a simple diagnostics page restricted to admins.

---

# 18. n8n Integration Boundary

n8n must be optional.

The Soul Core must function without n8n.

Create a small automation boundary capable of sending selected domain events to a configured webhook.

Examples:

```text
soul.memory.core_created
soul.relationship.wound_created
soul.action.rejected
soul.provider.failed
```

Requirements:

* Disabled by default
* Configured through environment variables
* Signed or authenticated when enabled
* Timeout protected
* Retry policy documented
* Failure must not corrupt the canonical soul transaction
* No secret or private-thought leakage

A supervised asynchronous job or durable job system may be used when justified.

Do not build elaborate n8n workflows unless required to prove the integration boundary.

Document example payloads.

---

# 19. Cinema Integration

The server reportedly has a tool or service called “Cinema.”

First determine exactly what it is.

Document:

* Installation path
* Version
* Purpose
* Interface
* Whether it is relevant to testing, recording, visualization, media, browser automation, or another function

Do not invent an integration based on the name.

If it is useful to this milestone, add only a minimal, isolated integration.

If it is not relevant, document why it was not used.

---

# 20. Security Requirements

Implement reasonable protections for the milestone:

* Server-side authorization
* CSRF protection
* Secure session handling
* Validated structured provider output
* Escaped user-generated content
* Input length limits
* Rate limiting for expensive provider actions
* Timeouts
* Request-size limits
* Secret redaction
* Safe error messages
* No private-thought leakage
* No direct model-driven database mutation
* No dynamic atom creation from untrusted input
* No unsafe term deserialization
* No shell execution based on scene dialogue

Run the appropriate Elixir security and quality tools when compatible.

Document findings and fixes.

---

# 21. Developer Experience

Provide:

```text
README.md
docs/architecture.md
docs/domain-model.md
docs/soul-rules.md
docs/testing.md
docs/playwright.md
docs/environment-audit.md
docs/security.md
docs/n8n-integration.md
docs/cinema-audit.md
.env.example
```

The README must include exact commands for:

* Installing dependencies
* Configuring PostgreSQL
* Creating the database
* Running migrations
* Seeding development data
* Starting Phoenix
* Running ExUnit
* Running Playwright
* Opening the Playwright report
* Running the complete verification suite

Create convenient scripts or aliases such as:

```text
mix setup
mix verify
npm run test:e2e
npm run test:e2e:headed
npm run test:e2e:ui
npm run test:e2e:report
```

Adapt these to the actual project.

---

# 22. Seed Scenario

Provide a deterministic development seed with:

## NPC

```text
Name: Vael
Role: Proud former guardian
Core value: Loyalty must be earned
Fear: Depending on someone who will later betray him
Desire: To protect others without appearing vulnerable
Speech style: Controlled, blunt, defensive
```

## Player

```text
Name: Goose
Role: Unpredictable ally
```

## Starting relationship

```text
affinity: 10
trust: 25
respect: 45
fear: 5
anger: 20
gratitude: 10
debt: 0
softening: 15
hardening: 35
wound: 20
```

Create seed events that allow developers to demonstrate:

* Protection
* Betrayal
* Apology
* Rebuilding trust
* Illegal action rejection
* Memory retrieval
* Wound formation
* Core-memory promotion

Use this scenario in documentation and selected E2E tests.

---

# 23. Visual Design Direction

Use a restrained dark interface suitable for the Sovereign Soul Engine.

Suggested mood:

* Gothic
* Technical
* Psychological
* Clean rather than cluttered
* Black, charcoal, muted green, deep teal, and restrained crimson accents

Accessibility and readability matter more than decoration.

Do not allow styling work to delay the functional and tested core.

---

# 24. Execution Phases

Execute the work in these phases.

## Phase 0 — Audit

* Inspect environment
* Identify existing code
* Check Git state
* Confirm tools and services
* Document findings
* Create branch

Stop and report only if there is a genuine destructive-risk blocker.

Otherwise continue.

## Phase 1 — Scaffold

* Create Phoenix LiveView project
* Configure PostgreSQL
* Establish domain contexts
* Add basic authentication and authorization
* Add initial migrations
* Establish test configuration

Run tests.

Commit stable work.

## Phase 2 — Deterministic domain core

* Relationships
* Emotions
* Events
* Memory scoring
* Memory decay
* Memory consolidation
* Actions
* Consequences
* Ledger
* Ecto.Multi workflows

Write unit and integration tests first or alongside implementation.

Run tests.

Commit stable work.

## Phase 3 — OTP runtime

* Registry
* DynamicSupervisor
* NPCServer
* SceneServer
* PubSub
* Crash recovery
* Idle shutdown
* Concurrency handling

Run tests.

Commit stable work.

## Phase 4 — Provider boundary

* Provider behavior
* Fake provider
* DeepSeek provider
* Structured validation
* Timeout handling
* Failure handling
* Prompt-injection defenses

Run tests.

Commit stable work.

## Phase 5 — LiveView vertical slice

* Dashboard
* NPC profile
* Scene
* Soul Inspector
* Memory Vault
* Soul Ledger
* Event Injector
* Live PubSub updates

Run LiveView tests.

Commit stable work.

## Phase 6 — Playwright

* Install or connect existing Playwright
* Configure deterministic E2E environment
* Implement all required critical scenarios
* Capture artifacts
* Eliminate flakiness
* Run complete suite repeatedly

Commit stable work.

## Phase 7 — Hardening

* Security review
* Accessibility review
* Concurrency review
* Error-state review
* Documentation
* n8n boundary
* Cinema audit
* Final verification

Run every verification command.

Commit final stable work.

---

# 25. Progress Reporting

During execution, report meaningful progress rather than narrating every shell command.

After each phase report:

```text
Phase:
Implemented:
Files changed:
Tests run:
Passed:
Failed:
Warnings:
Fixes made:
Next phase:
```

When a test fails:

1. Inspect the failure
2. Identify the actual cause
3. Fix the implementation or test
4. Re-run the smallest relevant test
5. Re-run the larger affected suite
6. Record the result

Do not disable legitimate tests merely to obtain green output.

Do not weaken assertions to hide defects.

---

# 26. Final Verification

Before declaring completion, run:

* Formatting checks
* Compilation with warnings treated seriously
* Static analysis where supported
* Full ExUnit suite
* Full LiveView test suite
* Full Playwright Chromium suite
* Cross-browser critical-path suite where supported
* Security checks
* Migration from a clean test database
* Seed execution
* Production build or release compilation
* Application restart
* Critical Playwright smoke test after restart

Run the complete critical suite at least twice to detect order dependence or flakiness.

Inspect:

* Browser console
* Phoenix logs
* Database errors
* Playwright traces
* Failed network calls
* LiveView disconnects

---

# 27. Definition of Done

The Soul Core is only complete when all of the following are true:

* Phoenix application starts cleanly
* Database can be created from migrations
* Development seeds work
* NPCs can be created
* Scenes can be created
* Dialogue can be submitted
* Fake provider returns deterministic structured responses
* DeepSeek provider is implemented behind configuration
* Public speech and private thought remain separated
* Events create deterministic relationship changes
* Memories are created, scored, ranked, and persisted
* Actions are validated before resolution
* Illegal actions cannot mutate state
* Consequences are atomic
* Ledger entries explain canonical mutations
* LiveView updates connected clients in real time
* NPC process crashes recover safely
* State survives page reload and process restart
* Authorization protects private thoughts and event injection
* n8n is optional
* Cinema has been correctly identified and documented
* ExUnit suite passes
* Playwright critical suite passes
* No unexplained browser console errors remain
* Test artifacts are available
* Documentation is sufficient for another engineer to run the project
* Final report contains exact verification evidence

---

# 28. Final Deliverable Report

At completion, provide:

## Architecture

* Major contexts
* OTP supervision tree
* Database model
* Provider boundary
* Transaction strategy
* PubSub flow

## Implementation

* Important modules
* Important LiveViews
* Important migrations
* Important configuration

## Testing

* Total ExUnit tests
* Total Playwright tests
* Browser matrix
* Passed tests
* Failed or skipped tests
* Flakiness observations
* Artifact locations

## Security

* Controls implemented
* Risks found
* Risks fixed
* Remaining risks

## Operations

* Start command
* Test commands
* Environment requirements
* Database setup
* DeepSeek configuration
* n8n configuration
* Cinema findings

## Remaining roadmap

Only list genuine future work outside the Soul Core scope.

Do not describe unfinished required work as complete.

---

Begin with the environment and repository audit. Then proceed through the phases without waiting for approval unless continuing would risk destructive changes, expose credentials, or overwrite an unrelated existing project.
