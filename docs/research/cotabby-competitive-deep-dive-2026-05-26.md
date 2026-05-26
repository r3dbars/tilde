# Cotabby Competitive Deep Dive

Date: 2026-05-26

Seed: [FuJacob/cotabby](https://github.com/FuJacob/cotabby) and
[tabbyapp.dev](https://www.tabbyapp.dev/).

## Summary

Cotabby is the closest public peer to SteadyType: a macOS menu bar app that
watches the focused text field, runs local autocomplete, renders ghost text near
the caret, and accepts with Tab. The strongest lesson is not to chase
"everywhere" support. The strongest lesson is that trust breaks when the app is
silent, slow, misplaced, or too broad about permissions.

SteadyType should keep its narrower product stance: local-first, proof-gated,
default quiet in risky fields, and honest about why suggestions do not appear.

## Public Product Facts

- Core loop: Cotabby resolves the focused editable field through Accessibility,
  watches keyboard input, asks a local runtime for a continuation, renders ghost
  text near the caret, reconciles continued typing, and inserts on `Tab`.
  Source: [Cotabby architecture](https://raw.githubusercontent.com/FuJacob/cotabby/main/ARCHITECTURE.md).
- Website promise: open-source AI autocomplete for existing apps, on-device,
  no accounts, no analytics, and local model customization. Source:
  [tabbyapp.dev](https://www.tabbyapp.dev/).
- README loop: a menu bar app that watches the focused field, generates a
  continuation, renders ghost text, and accepts chunks with `Tab`. Source:
  [Cotabby README](https://raw.githubusercontent.com/FuJacob/cotabby/main/README.md).
- Engines: Apple Intelligence via Apple's FoundationModels on macOS 26+, plus
  local GGUF models through llama.cpp / llama.swift. Source:
  [Cotabby README](https://raw.githubusercontent.com/FuJacob/cotabby/main/README.md).
- Built-in open-source model choices include a fast Qwen 0.6B GGUF and a
  balanced Gemma E2B GGUF. Source:
  [Cotabby README](https://raw.githubusercontent.com/FuJacob/cotabby/main/README.md).
- Permissions: Accessibility, Input Monitoring, and Screen Recording. Cotabby
  says Accessibility reads focused text/caret/bounds, Input Monitoring detects
  typing and Tab, and Screen Recording captures local visual context. Source:
  [Cotabby privacy](https://www.tabbyapp.dev/privacy).
- Network claim: optional Sparkle update checks and explicit Hugging Face model
  downloads; no other app network requests. Source:
  [Cotabby privacy](https://www.tabbyapp.dev/privacy).
- Release signal: `v0.1.1-beta` on 2026-05-25 was a performance hotfix that
  restored an AX bounds gate and raised focus polling from 50ms to 80ms. Source:
  [Cotabby 0.1.1-beta](https://github.com/FuJacob/cotabby/releases/tag/v0.1.1-beta).

## Core Writing Loop

1. User installs a DMG and grants macOS permissions.
2. User chooses Apple Intelligence or an open-source local model.
3. User types in an app.
4. Cotabby reads nearby text and caret geometry through AX.
5. A short continuation appears as ghost text near the caret.
6. `Tab` accepts part of the suggestion.
7. `Esc`, navigation, or continued typing dismisses or diverges.

Transfer to SteadyType: keep the loop, but keep our safer acceptance contract:
`Tab` accepts the next word only, full accept remains a separate action, and
risky fields stay blocked until proof exists.

## Delight Moment

The delight is the first time ghost text appears exactly where the user is
already writing and `Tab` inserts a useful next word without app switching. The
public site explicitly sells that flow as staying in the apps the user already
uses. Source: [tabbyapp.dev](https://www.tabbyapp.dev/).

## Annoyance Moment

The annoyance is not a bad suggestion by itself. The real trust breaks are:

- no suggestion after permissions and model setup,
- delayed typing or missed input,
- overlay on the wrong display,
- support claims broader than real app behavior,
- unclear permission boundaries.

Public examples:

- ["No suggestions at all" issue](https://github.com/FuJacob/cotabby/issues/195)
- [typing delay in Outlook web](https://github.com/FuJacob/cotabby/issues/226)
- [wrong external monitor overlay](https://github.com/FuJacob/cotabby/issues/193)
- [does not do anything with any engine](https://github.com/FuJacob/cotabby/issues/256)
- [GGUF launch deadlock](https://github.com/FuJacob/cotabby/issues/262)

## Compatibility Findings

Cotabby claims broad app reach, but its own FAQ says compatibility depends on
what each app exposes through Accessibility and that some apps are hit or miss.
Source: [tabbyapp.dev FAQ](https://www.tabbyapp.dev/).

Known public demand and risk areas:

- Mail, Notes, Slack, Notion, messages, Gmail/browser text areas, Chrome,
  Outlook, and Discord are named in public copy.
- Google Docs support is requested publicly. Source:
  [Google Docs request](https://github.com/FuJacob/cotabby/issues/264).
- Browser webmail is a concrete lag risk. Source:
  [Outlook web lag issue](https://github.com/FuJacob/cotabby/issues/226).
- Multi-display placement needs explicit proof. Source:
  [external monitor overlay issue](https://github.com/FuJacob/cotabby/issues/193).

SteadyType should keep Chrome support limited to local textarea/contenteditable
fixtures and keep webmail blocked until disposable reply proof exists. The
webmail class should include Gmail, Outlook, Yahoo Mail, Fastmail, Proton Mail,
and iCloud Mail because the risk is browser-hosted mail composition, not one
brand.

## Privacy And Security Analysis

High-confidence facts:

- Cotabby publicly claims no accounts, no cloud processing, no analytics, and no
  remote logging of text, keystrokes, or suggestions. Source:
  [Cotabby privacy](https://www.tabbyapp.dev/privacy).
- It asks for Screen Recording for visual context. Source:
  [Cotabby privacy](https://www.tabbyapp.dev/privacy).
- It reads clipboard contents at suggestion time, says it does not cache, store,
  or transmit them. Source:
  [Cotabby privacy](https://www.tabbyapp.dev/privacy).

Inference:

- Local-only is necessary but not enough. Accessibility, Input Monitoring,
  clipboard access, and Screen Recording together create a large local trust
  surface. SteadyType should keep screenshot/raw context opt-in, avoid clipboard
  context by default, and make redacted proof export the default support path.

## Runtime And Model Analysis

Facts:

- Cotabby uses Apple Intelligence where available and local GGUF through
  llama.cpp/llama.swift otherwise. Source:
  [Cotabby README](https://raw.githubusercontent.com/FuJacob/cotabby/main/README.md).
- The public release stream includes a runtime hang report with Qwen3.5 GGUF
  selection. Source:
  [GGUF launch deadlock issue](https://github.com/FuJacob/cotabby/issues/262).
- The latest release hotfix specifically addressed AX load and focus polling.
  Source:
  [Cotabby 0.1.1-beta](https://github.com/FuJacob/cotabby/releases/tag/v0.1.1-beta).

Transfer to SteadyType:

- Keep one app-owned runtime.
- Keep model install/repair visible in Settings.
- Keep latency proof fresh.
- Avoid broad bring-your-own model UX before runtime failures are contained.

## Do Not Copy

- Do not copy Cotabby code, assets, UI, branding, app names, icons, copy, or
  trade dress.
- Do not use Cotabby's AGPL implementation as a source for SteadyType code.
- Do not copy the "works anywhere" posture.
- Do not require Screen Recording for the MVP path.
- Do not read clipboard by default.
- Do not turn local fixtures into broad browser support claims.

## Safe Ideas To Adapt

- Explain why suggestions are unavailable in plain language.
- Keep per-app controls obvious.
- Keep local model readiness visible.
- Treat AX polling cost as product risk.
- Make browser webmail a named blocked/proof-needed class.
- Keep screenshot and raw traces opt-in.
- Use source-backed compatibility matrices instead of broad claims.
