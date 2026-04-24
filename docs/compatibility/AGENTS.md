# Compatibility Docs Guide

This folder defines which editors the lab should support, how to test them, and when to stop.

- Keep docs concrete and short.
- Treat bundle IDs as the source of truth for app support.
- Keep privacy requirements explicit: no secure fields, no raw typed text storage, no cloud-only path.
- Do not imply broad editor support until the app passes the ladder here.
- Do not edit Swift source, tests, or scripts from this folder's documentation slice.
