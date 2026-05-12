# Claude Code Guide

Swift tests live here.

Target map:

- `AutocompleteLabCoreTests/`: pure policy, text, geometry, engine, tracing, runtime value, and compatibility tests.
- `AutocompleteLabAppTests/`: app wiring, settings, UI state, runtime installer, proof command, and native controller tests.

Rules:

- Add tests with each meaningful behavior change.
- Keep pure core tests separate from AppKit or file-system-heavy app tests.
- Prefer narrow test filters while iterating, then run a broader lane before commit.
