# Replay Eval Executable Guide

This target owns the local-only replay CLI and process bridge to the app's batch model script.

- Depend only on `AutocompleteLabCore`.
- Keep personal corpus text in memory; persist aggregate trend rows only.
- Build personalized memory from journal days strictly before each replay case.
- Clean model output through the same core cleaner used by the app.
- Score every cleaned output both raw and through the production core display gates.
- Keep prompt format explicit in every aggregate row; comparisons are within-model.
- Load a batch model once per run and always clean up the child process.
