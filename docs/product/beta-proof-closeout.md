# Beta Proof Close-Out

This is the beta proof lane. It is not beta readiness by itself.

Use the front door:

```bash
./script/beta_proof_closeout.sh
```

It checks the onboarding proof gates, keeps packaged latency explicit, and
points at the dogfood ledger. It does not cut, notarize, publish, deploy, grant
Accessibility, or turn missing human proof into green.

## Required Order

1. Re-proof onboarding on a clean macOS user account.
2. Run packaged latency against the notarized app after Accessibility is
   granted for that exact packaged app.
3. Dogfood for 5 consecutive green days.
4. Invite 3-5 testers only after the 5-day dogfood gate is green.

## Onboarding Re-Proof

Run:

```bash
./script/check_onboarding_walkthrough_proof.py
./script/check_onboarding_permission_qa.sh --check
```

If either command fails, keep beta blocked. A pass row needs real clean-user
proof, not a copied template.

## Packaged Latency Proof

After a notarized app exists and Accessibility is granted for that app:

```bash
./script/beta_proof_closeout.sh --run-packaged-latency --target textedit-model-latency --app-bundle dist/SteadyType.app
```

Use the installed notarized app path if the app was installed from the DMG.
Do not count source-tree latency or unsigned app latency as packaged proof.

## Dogfood Ledger

Record one row per day. Do not paste raw typed text, prompts, URLs, document
names, screenshots, recipients, subject lines, or trace excerpts.

| Date | Build SHA/version | Reached-for-it | Quality 1-5 | Trust incident | Would-keep-on | Notes |
| --- | --- | --- | ---: | --- | --- | --- |
|  |  | yes/no |  | yes/no | yes/no | no private text |
|  |  | yes/no |  | yes/no | yes/no | no private text |
|  |  | yes/no |  | yes/no | yes/no | no private text |
|  |  | yes/no |  | yes/no | yes/no | no private text |
|  |  | yes/no |  | yes/no | yes/no | no private text |

A green day means:

- `Reached-for-it` is `yes`.
- `Quality 1-5` is `4` or `5`.
- `Trust incident` is `no`.
- `Would-keep-on` is `yes`.
- No beta readiness blocker appeared that day.

Five green days must be consecutive. One trust incident resets the count.

## Tester Wave Checklist

Do not start this until the dogfood ledger has 5 consecutive green days.

- Choose 3-5 testers only.
- Use the current notarized DMG and current private-beta packet.
- Give each tester one 15-minute day-zero onboarding call.
- Keep normal writing surfaces to TextEdit, Notes, Obsidian, and Chrome local
  textarea/contenteditable fixtures.
- Keep Mail, Codex, Claude, chat apps, terminal hosts, public browser pages,
  browser webmail, search, login, payment, address, URL, secure, and private
  fields out of normal beta coverage.
- Each tester runs 2-3 short sessions over 3 days.
- Each session ends with a redacted Privacy Bundle export.
- Stop the wave on wrong insertion, duplicate insertion, focus steal,
  sensitive-field suggestion, unsafe Tab, mock fallback, external model server
  setup, failed in-app model setup, stale notarization, or stale checksums.

## Missing Until Observed

- Current clean-user onboarding walkthrough proof.
- Current onboarding permission QA completion.
- Current packaged latency proof from the notarized app.
- Five consecutive green dogfood days.
- The 3-5 tester wave.
