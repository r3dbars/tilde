# Deep Dive Scorecard - 2026-05-06

This is the current rating for the lab app after the trust-first hardening pass.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 7/10.

The app is now credible as a private lab build. It is strongest in TextEdit and
Notes, good enough to keep testing in Chrome textareas, and still not proven
enough in Codex, Claude Code, or Obsidian to call universal. The biggest product
risk is not raw typing latency anymore; it is trust. The app must never show in
the wrong field, never steal normal keys, and never keep repeating unhelpful
suggestions.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 8/10 | Non-autocomplete keys pass through immediately and only mark typing async. |
| Keyboard capture safety | 7/10 | The tap is only active while suggestions are visible, now starts before the panel appears, and logs latency. |
| Acceptance reliability | 7/10 | Tab/backtick are verified after insertion, but focus checks still depend on app AX behavior. |
| Placement confidence | 6/10 | Strong with caret bounds, medium with mirror placement, still weak in apps that hide editor geometry. |
| Self-healing placement | 7/10 | Falls back from inline to mirror and records confidence, but needs more app fixtures. |
| TextEdit support | 9/10 | Best reference target with current real smoke proof. |
| Notes support | 8/10 | Good support with key-event insertion, but rich text remains a higher-risk surface. |
| Chrome textarea support | 7/10 | Real textarea smoke passes; contenteditable, Monaco, ProseMirror, and CodeMirror still need fixtures. |
| Obsidian support | 5/10 | Safer than before because detached suggestions are suppressed, but current proof needs a fresh no-detached run. |
| Codex support | 6/10 | Synthetic caret path is promising; manual proof still pending. |
| Claude Code support | 4/10 | Profile exists, but live proof is still missing. |
| Output relevance | 7/10 | Prompts and cleaners are short and local; sentence-boundary guidance is now better. |
| Word completion quality | 7/10 | Fast ranker path is useful, repeated word misses are now suppressed, punctuation suffixes are rejected. |
| Non-annoyance | 7/10 | Esc, typed-over tracking, repetition suppression, and useful-rate gates are in place. |
| Privacy | 8/10 | Local-first, secure fields suppressed, diagnostics redact text by default. Raw trace and screenshots stay opt-in. |
| Onboarding | 7/10 | Permission flow exists, the settings surface now shows the global control state, and debug tools are less prominent. |
| User control | 7/10 | Per-app disable exists, and a persisted global pause/resume control now stops suggestions everywhere. |
| Diagnostics | 8/10 | Strong trace, placement, latency, and insertion signals. Needs a simpler top summary. |
| Automated tests | 8/10 | Core has broad tests and script self-tests. App-layer services still need seams. |
| Real-app smoke | 7/10 | TextEdit and Chrome are automated; Codex and Claude Code are manual-gated; Obsidian needs refresh. |
| Release readiness | 6/10 | Bundle checks, signing, and version metadata exist; model distribution is not self-contained yet. |
| Architecture | 7/10 | Core boundaries are solid; AppDelegate is still too large. |

## Research Notes

- Apple documents event taps as low-level input filters. That means the callback
  must stay tiny, predictable, and fast.
- Apple documents event tap timeout disable events. The app should keep
  re-enabling the tap and treat any timeout as a serious regression.
- Apple accessibility text APIs provide focused elements, selected text ranges,
  and bounds-for-range. Those are the right primitives when an app exposes them,
  but many browser and Electron editors expose incomplete geometry.

Primary references:

- https://developer.apple.com/documentation/coregraphics/quartz-event-services
- https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout
- https://developer.apple.com/documentation/applicationservices/axuielement
- https://developer.apple.com/documentation/applicationservices/kaxselectedtextrangeattribute
- https://developer.apple.com/documentation/applicationservices/kaxboundsforrangeparameterizedattribute

## What Changed In This Pass

- Word-completion cleaner now rejects punctuation suffixes like `ing.`.
- Repetition suppression now applies to repeated word-completion misses, not only
  tiny suffixes.
- Phrase prompts now ask for the next sentence after sentence-ending punctuation.
- Trace eval can now fail on low useful rate and repeated unaccepted suggestions.
- Accept-ready suggestions now start keyboard capture before the visual panel is
  shown.
- Codex and Claude Code prompt detection now allows prompt-like AXGroup and
  AXWebArea wrappers without opening up non-prompt content.
- The generated app bundle now includes version metadata, and the bundle checker
  requires it.
- The menu now has a global Pause/Resume Suggestions control.
- Debug-heavy diagnostics, model folder, nudge, and reset actions now live under
  a Debug submenu.

## Next Highest-Leverage Work

1. Add visible app management beyond the current-app toggle.
2. Add Chrome fixture pages for textarea, contenteditable, Monaco, CodeMirror,
   and ProseMirror.
3. Refresh Obsidian proof under the current no-detached-suggestion rule.
4. Finish manual-gated Codex and Claude Code smoke proof.
5. Split AppDelegate into testable services around focused text polling,
   suggestion coordination, insertion verification, and tracing.
6. Make the beta artifact self-sufficient with model download or bundling.
