# Compatibility Matrix

Current compatibility stance for the lab build.

| App | Status | Render | Insert | Proof |
| --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | AX selected text, value fallback | recorded manual smoke pass |
| Notes | supported | inline, mirror fallback | key events, AX selected text fallback | recorded manual smoke pass |
| Obsidian | supported | mirror | AX then key events, key fallback | recorded manual smoke pass |
| Chrome | supported for local text fields | mirror | AX value replacement, key fallback | recorded local textarea pass |
| Mail | diagnostics only | disabled | disabled | blocked until safe compose adapter exists |
| Atlas | unsupported | disabled | disabled | blocked until focused AX element is reliable |

Run:

```bash
./script/manual_smoke_status.sh --require-all
```

The four supported apps must stay green before beta work.
