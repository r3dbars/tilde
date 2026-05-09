# Beta Privacy Data Checklist

Last checked: 2026-05-08.

This is the reviewer map for what the beta can collect or store.

| Field | Stored by default | Retention | Opt-in state | Can leave the Mac |
| --- | --- | --- | --- | --- |
| Typed text near cursor | No, length only | No raw default retention | Raw local debug tracing only | No |
| Text after cursor | No, length only | No raw default retention | Raw local debug tracing only | No |
| System prompt | No, length only | No raw default retention | Raw local debug tracing only | No |
| User prompt | No, length only | No raw default retention | Raw local debug tracing only | No |
| Model output | No, length only | No raw default retention | Raw local debug tracing only | No |
| Visible suggestion | No, length only | No raw default retention | Raw local debug tracing only | No |
| Accepted text | No, length/fingerprint only | RAM checks at 2s/10s/30s, then cleared | Raw local debug tracing only | No |
| Remaining visible suggestion | No, length only | No raw default retention | Raw local debug tracing only | No |
| Screenshot image | No | No default retention | Screenshot proof only | No |
| Screenshot path | No | No default retention | Screenshot proof only | No |
| URL | No, length only if seen in metadata | No raw default retention | Raw local debug tracing only | No |
| Document title or filename | No, length only if seen in metadata | No raw default retention | Raw local debug tracing only | No |
| Recipient | No, length only if seen in metadata | No raw default retention | Raw local debug tracing only | No |
| Subject line | No, length only if seen in metadata | No raw default retention | Raw local debug tracing only | No |
| App bundle identifier | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Field kind | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Request mode | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Render and insertion mode | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Timing and latency | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Counters and scores | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Failure or suppression reason | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| HMAC fingerprints | Yes | Until traces are deleted | Default redacted diagnostics | Yes, only if user shares the redacted export |
| Model asset name and readiness state | Yes | Until traces are deleted or logs rotate | Default diagnostics | Yes, only if user shares diagnostics |

## Sharing Rule

The default support artifact is the redacted privacy bundle. It can leave the
Mac only when the tester chooses to share it.

Raw text traces and screenshots are local debug opt-ins. They should be used
only for a named debug session and deleted afterward.

## Checks

Run:

```bash
./script/check_redacted_report_export.sh
./script/check_current_build_privacy_export.sh
./script/delete_local_traces_self_test.sh
```
