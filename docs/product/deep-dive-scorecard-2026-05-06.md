# Deep Dive Scorecard - 2026-05-06

This is the current rating for the lab app after the trust-first hardening and
Chrome editor compatibility passes.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 8/10.

The app is now a strong private lab build. It has automated real-app proof in
TextEdit and five Chrome browser editor shapes: textarea, contenteditable,
CodeMirror-style contenteditable, Monaco-like, and ProseMirror-like. Notes and
Obsidian have recorded manual proof, but Codex and Claude Code remain
manual-gated and unproven enough that the app is not yet universal. The biggest
product risk is still trust: the app must never show in the wrong field, never
steal normal keys, and never keep repeating unhelpful suggestions.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 8/10 | Non-autocomplete keys pass through immediately; diagnostics now prove event-tap work stays in microseconds during smoke runs. |
| Keyboard capture safety | 8/10 | The tap is active only while suggestions are visible, starts before the panel appears, logs latency, and ignores its own synthetic insertion events. |
| Acceptance reliability | 8/10 | Tab/backtick are verified after insertion across TextEdit and five Chrome fixture shapes. |
| Placement confidence | 7/10 | Strong with caret bounds and now better proven with Chrome mirror placement, but still medium when apps hide editor geometry. |
| Self-healing placement | 8/10 | Falls back from inline to mirror, records confidence, and now has browser fixture proof for textarea and multiple rich-editor shapes. |
| TextEdit support | 9/10 | Best reference target with current real smoke proof. |
| Notes support | 8/10 | Good support with key-event insertion, but rich text remains a higher-risk surface. |
| Chrome textarea support | 9/10 | Automated smoke passes with two verified accepts. |
| Chrome contenteditable support | 8/10 | Automated smoke passes after switching Chrome to key-event insertion and rich-whitespace verification. |
| Chrome editor-like support | 8/10 | Automated CodeMirror-style contenteditable fixture passes with two verified accepts. |
| Chrome Monaco-like support | 8/10 | Local dependency-free Monaco-shaped fixture now has its own automated smoke path and proof label. |
| Chrome ProseMirror-like support | 8/10 | Local dependency-free ProseMirror-shaped fixture now has its own automated smoke path and proof label. |
| Obsidian support | 7/10 | Safer than before because detached suggestions are suppressed and recorded proof exists, but broader CodeMirror proof still needs refresh. |
| Codex support | 6/10 | Synthetic caret path is promising; manual proof still pending. |
| Claude Code support | 4/10 | Profile exists, but live proof is still missing. |
| Output relevance | 8/10 | Prompts and cleaners are short and local; prompt-label echoes and punctuation suffixes are stripped. |
| Word completion quality | 8/10 | Fast ranker path is useful, repeated word misses are suppressed, punctuation suffixes are rejected, and partial accept keeps remaining text alive. |
| Non-annoyance | 8/10 | Esc, typed-over tracking, repetition suppression, useful-rate gates, pause control, and synthetic-event suppression are in place. |
| Privacy | 8/10 | Local-first, secure fields suppressed, diagnostics redact text by default. Raw trace and screenshots stay opt-in. |
| Onboarding | 7/10 | Permission flow exists, the settings surface now shows the global control state, and debug tools are less prominent. |
| User control | 8/10 | Per-app disable exists, and a persisted global pause/resume control now stops suggestions everywhere. |
| Diagnostics | 8/10 | Strong trace, placement, latency, and insertion signals. Needs a simpler top summary. |
| Automated tests | 9/10 | Core has broad tests, 202 Swift tests pass, and script self-tests cover manual and real-app smoke harnesses. |
| Real-app smoke | 9/10 | TextEdit and five Chrome fixture shapes are automated; Codex and Claude Code remain manual-gated. |
| Release readiness | 7/10 | Bundle checks, signing, version metadata, and a hard preferred-model asset gate exist; model distribution is still not self-contained yet. |
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
- Runtime-ready transitions now re-arm the current field so first typing during
  model warmup does not get stranded.
- Chrome smoke now tests textarea, contenteditable, editor-like, Monaco-like,
  and ProseMirror-like local fixtures, with fixture-specific proof rows.
- Chrome now prefers key-event insertion with AX value replacement as fallback,
  because rich browser editors can report AX replacement success while moving
  the cursor in surprising ways.
- Synthetic key-event insertion no longer makes the keyboard tap treat its own
  inserted text as user typing.
- Insertion verification accepts rich-editor non-breaking-space equivalents.
- Partial word acceptance no longer lets cadence or fast-candidate misses erase
  the remaining visible suggestion before full accept.
- Beta and package readiness now fail clearly when the preferred Qwen3.5 4B MLX
  model asset is missing, malformed, or too small.

## Next Highest-Leverage Work

1. Finish manual-gated Codex and Claude Code smoke proof.
2. Try real production Monaco and ProseMirror surfaces after the local fixtures
   stay green.
3. Refresh Obsidian proof under the current no-detached-suggestion rule.
4. Add visible app management beyond the current-app toggle.
5. Split AppDelegate into testable services around focused text polling,
   suggestion coordination, insertion verification, and tracing.
6. Make the beta artifact self-sufficient with app-driven first-run model
   download or bundling.
