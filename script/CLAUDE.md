# Claude Code Guide

Local automation scripts live here.

Start with:

- `steadytype build` to build the app bundle without launching it.
- `steadytype test` for the fast pre-merge gate.
- `steadytype smoke` for the broad local smoke suite.
- `steadytype eval` for the checked-in quality suite.
- `steadytype release --check` before building or notarizing release artifacts.

Those are the five public operations. The existing focused scripts remain
internal implementation and diagnostic tools. Validate the facade with
`steadytype_self_test.sh`.

Rules:

- Keep scripts privacy-first and local by default.
- Product UX must not require users to run model servers.
- Every new script should have a narrow purpose and, when practical, a `*_self_test.sh`.
- Do not add another public facade operation without replacing one of the five.
- Avoid printing raw typed text, clipboard contents, prompts, URLs, or document names.
