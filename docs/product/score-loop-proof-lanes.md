# Score Loop Proof Lanes

Use this when the score loop is red and the next useful proof is not obvious.

The scorecard already says what is weak. This helper makes the next lanes easy
to scan without changing any score or rerunning a heavy beta gate.

```bash
./script/scorecard_next_proof_lanes.py
```

The output lists the lowest-scoring rows in
`docs/product/steadytype-product-scorecard.md` and prints each row's `Next Proof`
cell. It is read-only. It does not replace `./script/beta_readiness.sh
--check-only`, `./script/check_steadytype_scorecard.py`, or strict manual proof.

For long-running agent work, use the automation-ready view to skip lanes that
require a clean-user walkthrough, a manual permission grant, or another human
gate:

```bash
./script/scorecard_next_proof_lanes.py --automation-ready
```

For target-app coverage work, use the ranked app-surface queue:

```bash
./script/target_app_coverage_queue.py
```

That queue ranks value against proof risk and keeps beta-safe TextEdit, Notes,
and Obsidian polish ahead of prompt, chat, terminal, and hosted browser claims.

Self-test:

```bash
./script/scorecard_next_proof_lanes_self_test.sh
./script/target_app_coverage_queue_self_test.sh
```
