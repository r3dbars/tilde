# Runtime Network Egress Proof

Use this to prove the local-only typing path does not talk to the network while
Autocomplete Lab is running.

## Autocomplete-Time Check

Run this while Autocomplete Lab is open and a disposable local typing session is
active:

```bash
./script/check_runtime_network_egress.py \
  --phase autocomplete \
  --duration 30 \
  --interval 1 \
  --proof-out docs/product/runtime-network-egress-latest.md
```

Pass means the observer saw no non-loopback remote endpoints from the app
process during the window.

Fail means autocomplete-time egress happened and the beta privacy score cannot
claim local-only runtime proof.

## Model Setup Check

The one expected network path is model install or repair. Capture that as a
separate phase:

```bash
./script/check_runtime_network_egress.py \
  --phase model-setup \
  --duration 30 \
  --interval 1
```

Remote endpoints in `model-setup`, `model-download`, or `model-update` mode are
classified as setup/update traffic. They do not count as autocomplete-time
egress.

## Privacy Boundary

The proof stores only process/socket metadata:

- phase,
- process name and PID,
- sample count,
- remote endpoint count,
- unexpected endpoint count,
- allowed model setup/update endpoint count.

It does not store typed text, prompts, model output, screenshots, document
names, URLs, or trace lines.

## Self-Test

```bash
./script/check_runtime_network_egress_self_test.sh
```

The self-test verifies three cases:

- no remote endpoint during autocomplete passes,
- remote endpoint during autocomplete fails,
- remote endpoint during model setup passes as setup/update traffic.
