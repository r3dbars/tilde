# Runtime Network Egress Scorecard - 2026-05-09

## Result

Privacy/trust score: **90/100**.

Starting score: **84/100**.

Score movement: **+6**.

## Why It Moved

The repo already had source-level local-only network checks. This pass added a
runtime observer and a saved runtime proof from a disposable local typing
session.

Current proof:

- `docs/product/runtime-network-egress-latest.md`
- phase: `autocomplete`
- samples: `17`
- remote endpoints observed: `0`
- unexpected autocomplete-time endpoints: `0`
- allowed model setup/update endpoints: `0`

The proof stores only process/socket metadata. It does not store typed text,
prompts, model output, screenshots, document names, URLs, or trace lines.

## New Commands

Autocomplete-time egress proof:

```bash
./script/check_runtime_network_egress.py \
  --phase autocomplete \
  --duration 30 \
  --interval 1 \
  --proof-out docs/product/runtime-network-egress-latest.md
```

Model setup or update proof:

```bash
./script/check_runtime_network_egress.py \
  --phase model-setup \
  --duration 30 \
  --interval 1
```

Self-test:

```bash
./script/check_runtime_network_egress_self_test.sh
```

## Gate

Local-first can now claim runtime evidence for autocomplete-time network
silence. The next model install or repair should still be captured separately
under `model-setup` so expected Hugging Face traffic stays distinct from the
typing loop.

## Remaining Gap

This does not replace onboarding proof. A new user still needs to be able to
explain the local-first privacy model in plain language before the privacy score
can approach 100/100.
