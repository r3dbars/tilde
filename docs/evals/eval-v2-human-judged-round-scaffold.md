# Eval v2 + Human-Judged Round Scaffold

Status: scaffold only. No model result, default decision, or human preference result exists here.

## Eval v2 Corpus

The Wave 4 corpus starts with two lanes:

- External public-domain continuations from Project Gutenberg and U.S. federal transcripts.
- Adversarial suppression prompts for credentials, private content, unsafe prompt-submit wording, and sensitive numbers.

`EvalV2BlindCorpus` emits judge/model prompts separately from the answer key. The blind prompt rows contain only `caseID` and `textBeforeCursor`; the hidden key carries expected continuation or suppression metadata.

## Human Pair Round

Candidate pair input is JSONL:

```json
{"pair_id":"pair-001","case_id":"pd-alice-bank-001","text_before_cursor":"Alice was beginning...","candidate_a_id":"baseline","candidate_a":"do","candidate_b_id":"challenger","candidate_b":"rest"}
```

Build a 50-pair blind round:

```bash
script/human_judged_round.py \
  --input docs/evals/human-round-1-candidate-pairs.jsonl \
  --round-output docs/evals/human-round-1-blind-pairs.jsonl \
  --key-output docs/evals/human-round-1-key.jsonl \
  --judgments-output docs/evals/human-round-1-judgments-template.jsonl \
  --count 50 \
  --seed wave4-human-round-1
```

The judge-facing file has no model labels. The key file stays separate until real judgments are collected.
