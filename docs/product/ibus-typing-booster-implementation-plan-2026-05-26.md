# IBus Typing Booster Implementation Plan

Date: 2026-05-26

## Product Rule

SteadyType should feel calmer than an input-method candidate list. It should help only when the field is safe, the suggestion is useful, and the user has a clear escape hatch.

## Shipped In This Pass

1. Calmer default pace
   - Change new default tuning from Proactive to Normal.
   - Expected effect: fewer surprise suggestions on first install, more waiting for useful context.
   - Proof: `SuggestionAggressivenessTests`.

2. Broader secret-field suppression
   - Add KeePass/KeePassXC/Keeper/NordPass/Proton Pass/RoboForm/KeeWeb hints.
   - Add password-manager and terminal-password hints to AX classification and activation suppression.
   - Proof: `SensitiveTextFieldPolicyTests`, `AXFieldClassifierTests`, `CompletionActivationPolicyTests`.

3. Research artifacts
   - Add a sourced IBus deep dive, opportunity matrix, gap map, implementation plan, and scorecard.

## Next Best Small Steps

1. On-demand suggestion mode
   - Add a separate shortcut such as "Show Suggestion Once".
   - Do not use Tab for summon because Tab is the one-word accept key.
   - Trace reason: `manual-summon`.
   - Keep automatic suggestions on by default only for proven writing surfaces.

2. Learned suggestion removal
   - Add "Do not suggest this again" for the visible suggestion.
   - Use local redacted fingerprints unless raw Personal Capture is explicitly enabled.
   - Do not store raw user text in beta/customer modes.

3. Better "why off" surface
   - Use concise labels: paused, private field, browser needs proof, model not ready, fast typing, field silenced.
   - Keep Diagnostics detailed, Settings simple.

## Avoid

- Dense candidate pickers.
- Digit/F-key selection.
- Cloud fallback for autocomplete.
- Broad browser claims.
- Any code, UI, copy, assets, or trade dress from IBus Typing Booster.
