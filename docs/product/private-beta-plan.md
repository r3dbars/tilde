# Private Beta Plan

Goal: find out whether Autocomplete Lab helps real writing without breaking
trust.

Run this before inviting anyone:

```bash
./script/check_model_asset.py
./script/beta_readiness.sh
```

That creates:

- `dist/AutocompleteLab.zip`
- `dist/private-beta/README.md`
- `dist/private-beta/install-checklist.md`
- `dist/private-beta/model-asset.md`
- `dist/private-beta/feedback-log.md`
- `dist/private-beta/session-report.md`
- `dist/private-beta/checksums.txt`

If the model check fails, fix the local app-owned asset before packaging:

```bash
python3 -m pip install --user huggingface_hub
./script/download_mlx_model.py --model qwen35-4b
./script/check_model_asset.py
```

## Test Shape

- 3-5 people.
- One week.
- Start in TextEdit.
- Then Notes.
- Then Obsidian if they already use it.
- Chrome textarea is only a sanity check.

## What To Watch

- Did Tab feel predictable?
- Did word completion feel instant?
- Did suggestions appear in the right place?
- Did suggestions feel helpful or distracting?
- Did anything insert in a surprising place?
- Did the app ever appear in a private or unsupported field?

## Privacy Rule

- No user-managed model server.
- The app owns the local MLX runtime.
- Raw text traces are off unless the tester opts in locally.
- Debug screenshots are off unless the tester opts in locally.
- Do not ask for trace files unless the tester chose to export them.

## Stop Conditions

Stop the beta if:

- insertion happens in the wrong app,
- a suggestion appears over sensitive text,
- Tab becomes unreliable,
- the local model falls back to mock output,
- the app needs manual model/server setup,
- `./script/check_model_asset.py` fails on the tester machine,
- raw text or screenshot logging turns on without explicit local opt-in.

## After Each Session

Record one row in:

```text
dist/private-beta/feedback-log.md
```

Then follow:

```text
dist/private-beta/session-report.md
```

Run aggregate trace eval, check latency, and fix the top repeated miss before
adding more testers. Only inspect raw traces or screenshots when the tester
explicitly opted in.
