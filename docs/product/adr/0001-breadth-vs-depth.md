# ADR-0001: Breadth vs depth for app support

- Status: Accepted
- Date: 2026-06-13
- Supersedes: none
- Locked by: `Tests/AutocompleteLabCoreTests/BreadthVsDepthADRTests.swift`

## Context

SteadyType has one recurring product question: should suggestions try to work
*everywhere* (broad, generic support for any app), or only in a small set of
*proven* apps (narrow, proof-gated depth)?

That question has flip-flopped across branches, and the thrashing has cost us:

- "Universal-aggressive" support was added, then reverted. The revert restored
  the covenant: the fallback profile was `.blocked` and routing used
  `enforceKnownApps = true`, so unknown apps got nothing.
- Broad support was then re-added as "generic autocomplete support" in commit
  `2e16c5e7` ("Turn on generic autocomplete support", 2026-06-13): the fallback
  profile became the "Generic App" profile at the `.accept` rung, and
  `enforceKnownApps` became `false`.

Each swing produced real regressions — a red test-coverage gate, a relaxed
safety posture — and parallel work sessions pulling the codebase in opposite
directions at the same time.

This ADR exists to stop the oscillation. It records the decision of record and
locks the load-bearing invariants in a test so the next change can't flip them
silently.

## Decision

**Generic / broad support is ON, as of 2026-06-13.**

Concretely, the current code is the decision:

- The generic fallback profile (`AppCompatibilityProfile.fallback`, "Generic
  App") sits at the `.accept` rung over the native Accessibility path. An app
  with no custom profile can show and accept suggestions.
- Routing does not restrict itself to a known-apps allowlist:
  `CompatibilityRoutingSettings.mvp.enforceKnownApps == false`.

In typing-loop terms: the assist should feel useful in the apps people actually
write in, including ones we haven't hand-profiled — not silently dead everywhere
except a short list.

## Rationale

- A system-wide writing assist that only works in a handful of apps reads as
  broken, not as cautious. Users expect "near the caret, in the app I'm typing
  in."
- The per-app ladder still exists. Broad support is the *floor* for unprofiled
  apps; profiled apps (TextEdit, Notes, Obsidian, Claude, …) keep their
  tuned behavior on top.
- Breadth is safe *only because* the guardrails below hold regardless of how
  broad the fallback is. The fallback rung does not get a vote on the
  guardrails; the guardrails run first and independently.

## Non-negotiable guardrails

These hold no matter how broad support is. They are the reason `.accept` on the
generic fallback is acceptable. Broadening support must never relax any of them.

1. **Secure and sensitive fields are suppressed, always.**
   `CompatibilityRoutingSettings.mvp.suppressSecureFields == true`, and the
   `AXFieldClassifier` blocks `.secure`, `.search`, `.url`, `.form`,
   `.unprovenSurface`, and `.unknown` field kinds before the fallback rung is
   ever consulted. Password managers, IDEs, and system settings stay on the
   denylist (`CompatibilityProfileStore.defaultDenylist`).
2. **Prompt and send surfaces are never downgraded to "not a prompt".**
   Known send surfaces (Messages, Slack, Discord, Telegram) must never carry
   `promptAppSafetyMode == .notPrompt`. They are `.disabled`, `.clickOnly`, or
   `.wordOnly` — anything except the relaxed not-a-prompt mode. Risky prompt
   apps (ChatGPT, Atlas, Slack, Discord, …) stay fail-closed: render/insert
   disabled, `hardDisabled` kill switch, runtime state disabled or proof-only.
3. **No accidental submit or send.**
   Full acceptance stays off on chat and prompt surfaces
   (`supportsFullAcceptance == false`, `requiresNoSubmitAcceptanceProof`),
   acceptance is one-word-only where allowed, and the acceptance guards
   (`SuggestionAcceptanceGuard`, `KeyboardCaptureSafetyPolicy`) abort when the
   prompt target changes before an accept.

Broad support changes the *default for unprofiled apps*. It does not change any
of the three guardrails above.

## Proof required to keep broad support legitimate

Breadth is **on but on probation**: the guardrails make it safe, and proof keeps
it honest. To keep generic support legitimately on, we owe:

- **A measured wrong-field-safety proof across arbitrary apps.** With broad
  support enabled, demonstrate from a measured run — not from optimism — that
  suggestions never appear in or insert into secure, sensitive, search/URL/form,
  or send-submitting surfaces in apps that have *no custom profile* and reach the
  generic fallback. The point is to prove the guardrails actually catch the long
  tail of unprofiled apps, which is exactly the surface breadth opened up.
- The existing sensitive-field gate (`script/check_sensitive_field_proof.sh`,
  aggregated by `./script/beta_readiness.sh`) must stay green. It proves the
  classifier covers the sensitive categories; the arbitrary-app wrong-field
  proof above extends that coverage to the generic fallback path specifically.

Status of that arbitrary-app proof: **open / pending.** It is the obligation
that justifies keeping breadth on. Per repo convention, pending proof stays
pending — do not broaden support claims ahead of it, and do not mark it done
until a measured run exists.

## Consequences

Positive:

- The assist feels like a real system-wide tool in untested apps, instead of
  appearing broken outside a short allowlist.
- One recorded decision plus one lock test ends the per-session tug-of-war.

Negative / cost:

- The blast radius is larger. Correctness now leans on the field classifier and
  the guardrails behaving in apps we have never opened.
- We carry proof debt until the arbitrary-app wrong-field-safety proof lands.
- The guardrails and their lock test must stay honest; weakening either is a
  product safety change, not a cleanup.

## Locked invariants

`Tests/AutocompleteLabCoreTests/BreadthVsDepthADRTests.swift` fails if any of
these drift from this ADR:

- Unprofiled apps resolve to `CompatibilityProfileStore.defaultOnFallbackProfile`
  (the default-on "Generic App" rung)
- Secure fields are hard-blocked by `CompletionActivationPolicy` before any request
- Sensitive apps (password managers, system settings, terminals) stay denylisted
- Messages / Slack / Discord never carry `promptAppSafetyMode == .notPrompt`

## Revisiting this decision

If a future change wants to go back to narrow, proof-gated depth (fallback
`.blocked`, `enforceKnownApps == true`), that is allowed — but it is a decision,
not a quiet edit:

1. Add a new ADR (`0002-…`) that supersedes this one and states the new posture
   and why.
2. Update `BreadthVsDepthADRTests.swift` in the same change.

If that lock test goes red, that is the signal the covenant is being changed.
Do not weaken the assertions to make it pass — change the ADR, or revert.
