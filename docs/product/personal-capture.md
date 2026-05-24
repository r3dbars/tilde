# Personal Capture

Personal Capture is a local, opt-in Justin dogfood loop.

It writes daily Markdown on this Mac so SteadyType can learn from real writing,
accepted suggestions, and accepted-kept signals. It is not telemetry, not a
private beta requirement, and not enabled for customers or testers by default.

## Local Path

```text
~/Library/Application Support/SteadyType/Personal Capture
```

Files are named by day:

```text
YYYY-MM-DD.md
Episodes/YYYY-MM-DD.episodes.jsonl
Episodes/YYYY-MM-DD-dashboard.md
```

## What It Records

- new writing fragments observed in safe focused text fields,
- verified accepted suggestions,
- accepted-kept survival signals at 2s, 10s, 30s, 1m, 5m, field blur, and send,
- suggestion episode actions: shown, accepted, ignored, dismissed, typed past,
  deleted fast, and kept,
- model, prompt version, candidate source, placement, latency, app bundle ID,
  field identity, field kind, accept mode, and suggestion IDs,
- optional local reply context from visible page OCR when that dogfood capture is
  enabled and safe.

The first observed field snapshot is only a boundary marker. The journal starts
recording raw writing after SteadyType has a previous safe snapshot to compare.

The episode dashboard is a local Markdown scorecard. It shows episode counts,
accept/kept/delete signals, eval-case count, latency, and model/prompt rows
without needing to open the raw JSONL.

## Hard Blocks

Personal Capture must not write Markdown for:

- secure fields,
- password, passkey, OTP, login, payment, address, URL/search, API key, token,
  password-manager, private prompt/search, government ID, tax, insurance,
  medical, crypto wallet, and command-line fields,
- suppressed field kinds such as search, form, secure, URL, unknown, and
  unproven surfaces,
- browser-hosted pages that still need proof, including ChatGPT, Slack,
  Discord, Google Docs, Notion, browser search/address bars, developer tools,
  and unknown browser pages.

These blocks run before Markdown is written. Redaction is a backstop, not the
main safety mechanism.

## Controls

Settings owns the switch. Turning it off stops new writes. `Delete Personal
Capture` turns it off and removes the journal, episode JSONL, and dashboards.

Redacted Privacy Bundles do not include Personal Capture Markdown. Support
should not ask testers for these files.
