# ADR-0003: Tilde pricing and open core

- Status: Accepted
- Date: 2026-07-30
- Supersedes: none
- Scope: product decision only; no licensing, payment, or feature-gate code

## Context

Tilde needs a simple business model that pays for deeper personalization
without making the basic writing experience worse. The Tilde identity is being
introduced in [PR #326](https://github.com/r3dbars/steadytype/pull/326); this
record does not rename or change the app.

## Decision

Tilde has Free and one Pro plan.

| Plan | Price | Includes |
| --- | --- | --- |
| Free | $0 | Unlimited core local autocomplete, the native keyboard, core settings and privacy controls, basic usage stats, and public evals |
| Pro | $5/month or $50/year | Everything in Free, plus personal writing memory, screen-aware context, longer-term insights, and automatic model setup and optimization |

There are no extra paid tiers.

### Trial

New users get 30 days of full Pro with no card required. When the trial ends,
Tilde falls back cleanly to Free. Core autocomplete keeps working, and the user
is not pressured to subscribe to recover basic writing functionality.

### The free floor

Reliability, speed, privacy, and basic app compatibility are product quality,
not premium features. They must never be weakened or paywalled.

Free must include a working app-owned local model. Pro automation may choose,
install, or optimize a better setup for the user's Mac, but Free may not require
the user to run a separate model server or repair the basic setup by hand.

### Open-core boundary

The intended architecture is:

- **TildeCore**: public and MIT-licensed. It owns the dependable local
  autocomplete foundation and can build and be evaluated without private code.
- **TildePro**: private. It depends on TildeCore and owns the paid
  personalization, richer context, long-term insight, and model-optimization
  features.
- **TildeApp**: the official signed composition. It combines TildeCore with
  TildePro when the user has Pro, and continues to provide the complete Free
  experience without it.

Private code may depend on public core. Public core must not depend on private
code. The exact source visibility of the official TildeApp composition is still
to be decided before public release.

### Current MIT consequences

The repository is currently covered by the [MIT license](../../../LICENSE).
That means recipients may use, copy, modify, redistribute, sublicense, and sell
the code already published here if they keep the required notice.

Moving future work into TildePro does not take those rights back. Code already
published under MIT, including earlier personalization experiments in repository
history, remains available under MIT. Before public release, the repository and
build layout must be reviewed so only the intended TildeCore surface is public.
This ADR does not change the license.

### Honest personalization progress

The menu may summarize personalization with simple stages:

1. **Warming up**
2. **Learning your voice**
3. **Dialed in**

A stage may advance only from opted-in usage or eval evidence. Time installed,
days opened, purchases, and arbitrary animation are not evidence. The menu must
not use streaks, fake percentages, or progress that implies learning happened
when it did not.

Personal memory and screen-aware context remain explicit opt-ins and local-first.
Follow [ADR-0002](0002-personal-writing-memory-before-lora.md) for the memory
approach and [PRIVACY.md](../../../PRIVACY.md) for the data boundary. Basic
usage stats and public evals must not expose personal writing.

### Signed distribution, support, and security

Pro revenue pays for the official signed app, automatic updates, and direct
support as well as the Pro features. Free users still receive fixes needed to
keep the core app safe and dependable. Tilde must not delay a security fix,
leave a known vulnerability in Free, or create artificial breakage to make Pro
look safer.

Security work follows the
[threat model](../../security/threat-model.md). Basic compatibility remains
proof-based under [ADR-0001](0001-breadth-vs-depth.md); safer or more reliable
support is never a Pro-only advantage.

## Not authorized by this decision

This ADR does not authorize:

- payment or license-checking code,
- trial timers or feature gates,
- a new private repository,
- a license change,
- publication, release, or distribution changes.

Those require separate implementation decisions and proof.
