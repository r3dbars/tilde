#!/usr/bin/env python3
"""Meaning-based reply scorer: the "better ruler" for judging model replies.

Exact-match (golden_eval.py's word-overlap scorer) can't tell a great-but-
different reply from a bad one -- "sounds good" and "works for me" share zero
words but mean the same thing. This module scores SEMANTIC quality: how good
a `suggestion` is AS A REPLY, given the `golden_reply` a human actually sent
and the `prior_context` it was replying to.

    score(prior_context, golden_reply, suggestion) -> float in [0, 1]

Two scoring paths, auto-selected:

1. Embedding path (preferred): if `sentence-transformers` is importable, we
   embed golden_reply and suggestion with a small local model
   (all-MiniLM-L6-v2, cached under ~/.cache/steadytype-eval/models) and score
   via cosine similarity, with a light bonus for suggestion/prior_context
   relevance. No text ever leaves the machine -- HF_HUB_OFFLINE is set once
   the model is cached locally.

2. Heuristic fallback (what actually runs today): this machine's data volume
   had ~9.8 GiB free out of 1.8 TiB while a GPU experiment driver owned the
   box (see CLAUDE.md hard constraints for this task). `sentence-transformers`
   pulls in torch + transformers + tokenizers, a multi-GB dependency chain,
   purely to download over the network mid-experiment. That's the "too
   heavy" case the task anticipated, so this fallback is what ships:

     - token overlap (Jaccard) over a small hand-built synonym/stopword
       lexicon for common short-reply intents (agreement, decline, thanks,
       greeting, farewell, apology, scheduling words). This is what lets
       "sounds good" and "works for me" both normalize to the token
       {"AGREE"} and match -- plain bag-of-words would score them 0.
     - char-trigram cosine similarity as a secondary lexical-overlap signal
       (catches shared substrings, typos, proper nouns, numbers that the
       synonym table doesn't know about).
     - a length-ratio sanity penalty (a suggestion wildly shorter/longer
       than the golden reply is suspect even if the words it has overlap).
     - a light (weight 0.08, additive, capped) relevance-to-prior-context
       bonus using the same normalized-token Jaccard.

   This is a heuristic, not a semantic model: it will miss paraphrases that
   don't share tokens or synonym-table entries (e.g. "let's push it" vs
   "can we delay that"), and the synonym table only covers common short
   conversational replies (SteadyType's actual domain). Re-run --selftest
   after editing the synonym/stopword tables.

CLI:
    python3 script/reply_score.py --selftest
    python3 script/reply_score.py --jsonl PATH_OR_-   # {"prior","golden","suggestion"} per line
    python3 script/reply_score.py --prior P --golden G --suggestion S

Never writes anywhere in the repo. Any cached model / output the caller asks
to save belongs under ~/.cache/steadytype-eval/ (see CLAUDE.md).
"""
import argparse
import json
import math
import os
import re
import sys
from collections import Counter

CACHE_DIR = os.path.expanduser("~/.cache/steadytype-eval")
MODEL_CACHE_DIR = os.path.join(CACHE_DIR, "models")

# ---------------------------------------------------------------------------
# Optional embedding path. Only engaged if sentence-transformers is already
# importable -- this script never installs anything itself (installing a
# multi-GB torch/transformers chain mid-experiment is exactly the "too
# heavy" case documented above). Force the heuristic even if the package
# happens to be present with STEADYTYPE_FORCE_HEURISTIC=1.
# ---------------------------------------------------------------------------
_EMBEDDER = None
_EMBEDDINGS_AVAILABLE = False
if not os.environ.get("STEADYTYPE_FORCE_HEURISTIC"):
    try:
        os.environ.setdefault("HF_HOME", MODEL_CACHE_DIR)
        os.environ.setdefault("SENTENCE_TRANSFORMERS_HOME", MODEL_CACHE_DIR)
        from sentence_transformers import SentenceTransformer  # noqa: F401
        import numpy as _np  # noqa: F401

        _EMBEDDINGS_AVAILABLE = True
    except Exception:
        _EMBEDDINGS_AVAILABLE = False


def _get_embedder():
    global _EMBEDDER
    if _EMBEDDER is None:
        from sentence_transformers import SentenceTransformer

        os.makedirs(MODEL_CACHE_DIR, exist_ok=True)
        _EMBEDDER = SentenceTransformer("all-MiniLM-L6-v2", cache_folder=MODEL_CACHE_DIR)
        # Once cached locally, don't let later runs touch the network at all.
        os.environ["HF_HUB_OFFLINE"] = "1"
    return _EMBEDDER


def _cos_np(a, b):
    import numpy as np

    denom = (np.linalg.norm(a) * np.linalg.norm(b))
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def _score_embeddings(prior, golden, suggestion):
    model = _get_embedder()
    texts = [golden, suggestion, prior or ""]
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    golden_sim = _cos_np(vecs[0], vecs[1])
    relevance = _cos_np(vecs[1], vecs[2]) if (prior or "").strip() else 0.0
    len_pen = _length_penalty(golden, suggestion)
    raw = max(0.0, golden_sim) * len_pen
    final = raw + 0.08 * max(0.0, relevance)
    return round(max(0.0, min(1.0, final)), 4)


# ---------------------------------------------------------------------------
# Heuristic path
# ---------------------------------------------------------------------------

_TOKEN_RE = re.compile(r"[a-z0-9']+")

# Filler / function words, plus hedge verbs ("sounds", "seems") that carry
# little meaning on their own in short replies -- dropped entirely.
STOPWORDS = frozenset(
    """
    a an the is are was were be been to of in on at for and or but so
    do does did just really very quite about with as if than then there
    here also too will would can could should might must
    i you we they he she my your our their me him her us them it its
    that this sounds seems looks feels like
    """.split()
)

# Small hand-built synonym table for common short-reply "intents" -- this is
# the piece that lets semantically-equivalent short replies match even with
# zero shared vocabulary. Deliberately narrow: tuned to SteadyType's actual
# domain (chat/email reply suggestions), not general-purpose paraphrase.
_SYNONYM_CLUSTERS = {
    "AGREE": [
        "yes", "yeah", "yep", "yup", "sure", "definitely", "absolutely",
        "certainly", "agreed", "agree", "ok", "okay", "good", "great",
        "greats", "awesome", "perfect", "fine", "cool", "nice", "works",
        "work", "sounds good",
    ],
    "DISAGREE": [
        "no", "nope", "nah", "negative", "disagree", "cant", "can't",
        "cannot", "wont", "won't", "dont", "don't", "doesnt", "doesn't",
        "never", "unable",
    ],
    "THANKS": ["thanks", "thank", "thx", "ty", "appreciate", "appreciated"],
    "GREET": ["hello", "hi", "hey", "yo", "morning", "afternoon", "evening"],
    "BYE": ["bye", "goodbye", "cya", "seeya", "farewell"],
    "SORRY": ["sorry", "apologize", "apologies", "oops"],
    "TIME": [
        "tomorrow", "today", "tonight", "soon", "now", "later", "schedule",
        "meeting", "minute", "minutes", "hour", "hours",
    ],
}
SYNONYM_MAP = {
    word: canon for canon, words in _SYNONYM_CLUSTERS.items() for word in words
}


def _tokenize(text):
    return _TOKEN_RE.findall((text or "").lower())


def normalize_tokens(text):
    """Lowercase, tokenize, canonicalize known synonyms, drop stopwords."""
    out = []
    for tok in _tokenize(text):
        if tok in SYNONYM_MAP:
            out.append(SYNONYM_MAP[tok])
        elif tok in STOPWORDS:
            continue
        else:
            out.append(tok)
    return out


def _jaccard(set_a, set_b):
    if not set_a or not set_b:
        return 0.0
    inter = len(set_a & set_b)
    union = len(set_a | set_b)
    return inter / union if union else 0.0


def _char_ngrams(text, n=3):
    s = " ".join(_tokenize(text))
    if len(s) < n:
        return Counter([s]) if s else Counter()
    return Counter(s[i:i + n] for i in range(len(s) - n + 1))


def _cosine_counter(a, b):
    if not a or not b:
        return 0.0
    dot = sum(v * b.get(k, 0) for k, v in a.items())
    norm_a = math.sqrt(sum(v * v for v in a.values()))
    norm_b = math.sqrt(sum(v * v for v in b.values()))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def _length_penalty(golden, suggestion):
    len_g = len(_tokenize(golden))
    len_s = len(_tokenize(suggestion))
    if len_g == 0 and len_s == 0:
        return 1.0
    denom = max(len_g, len_s, 1)
    ratio = abs(len_s - len_g) / denom
    return max(0.5, 1.0 - 0.5 * ratio)


def _score_heuristic(prior, golden, suggestion):
    g_tokens = set(normalize_tokens(golden))
    s_tokens = set(normalize_tokens(suggestion))
    tok_sim = _jaccard(g_tokens, s_tokens)
    char_sim = _cosine_counter(_char_ngrams(golden), _char_ngrams(suggestion))

    golden_similarity = 0.7 * tok_sim + 0.3 * char_sim
    len_pen = _length_penalty(golden, suggestion)
    raw = golden_similarity * len_pen

    p_tokens = set(normalize_tokens(prior))
    relevance = _jaccard(p_tokens, s_tokens)
    final = raw + 0.08 * relevance
    return round(max(0.0, min(1.0, final)), 4)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def score(prior_context, golden_reply, suggestion):
    """Score `suggestion` as a reply, against `golden_reply`, given
    `prior_context`. Returns a float in [0, 1]; higher is better. Empty or
    whitespace-only suggestions always score 0."""
    if suggestion is None or not suggestion.strip():
        return 0.0
    if golden_reply is None or not golden_reply.strip():
        # No reference to judge against -- fall back to a capped
        # relevance-to-prior signal rather than claiming a real score.
        p_tokens = set(normalize_tokens(prior_context))
        s_tokens = set(normalize_tokens(suggestion))
        return round(min(0.5, _jaccard(p_tokens, s_tokens)), 4)

    if _EMBEDDINGS_AVAILABLE:
        try:
            return _score_embeddings(prior_context, golden_reply, suggestion)
        except Exception as exc:  # pragma: no cover - defensive
            sys.stderr.write(
                "reply_score: embedding path failed (%s), falling back to heuristic\n" % exc
            )
    return _score_heuristic(prior_context, golden_reply, suggestion)


def scoring_backend():
    return "sentence-transformers/all-MiniLM-L6-v2" if _EMBEDDINGS_AVAILABLE else "lexical-semantic-heuristic-v1"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _selftest():
    failures = []

    def check(label, cond, detail=""):
        status = "ok" if cond else "FAIL"
        print("  [%s] %s%s" % (status, label, (" -- " + detail) if detail else ""))
        if not cond:
            failures.append(label)

    print("backend: %s" % scoring_backend())

    prior = "Are you free at 3pm to go over the budget?"
    golden = "Sounds good, see you then."

    s_identical = score(prior, golden, golden)
    check("identical text ~1.0", s_identical >= 0.95, "got %.4f" % s_identical)

    suggestion_paraphrase = "Works for me, see you soon."
    s_paraphrase = score(prior, golden, suggestion_paraphrase)
    check(
        "paraphrase scores HIGH",
        s_paraphrase > 0.5,
        "got %.4f (golden=%r suggestion=%r)" % (s_paraphrase, golden, suggestion_paraphrase),
    )

    suggestion_offtopic = "The weather in Paris is lovely today."
    s_offtopic = score(prior, golden, suggestion_offtopic)
    check(
        "off-topic scores LOW",
        s_offtopic < 0.3,
        "got %.4f" % s_offtopic,
    )
    check(
        "paraphrase clearly beats off-topic",
        s_paraphrase > s_offtopic,
        "paraphrase=%.4f offtopic=%.4f" % (s_paraphrase, s_offtopic),
    )

    s_empty = score(prior, golden, "")
    check("empty suggestion scores 0", s_empty == 0.0, "got %.4f" % s_empty)
    s_empty_ws = score(prior, golden, "   \n\t ")
    check("whitespace-only suggestion scores 0", s_empty_ws == 0.0, "got %.4f" % s_empty_ws)

    # A second, unrelated-domain pair, to catch overfitting to the example above.
    golden2 = "No, I can't make it tomorrow, sorry."
    suggestion2_paraphrase = "Nope, tomorrow doesn't work for me, apologies."
    suggestion2_offtopic = "I just bought a new pair of running shoes."
    s2_para = score(prior, golden2, suggestion2_paraphrase)
    s2_off = score(prior, golden2, suggestion2_offtopic)
    check(
        "second paraphrase example beats off-topic",
        s2_para > s2_off and s2_para > 0.4,
        "para=%.4f off=%.4f" % (s2_para, s2_off),
    )

    print()
    if failures:
        print("SELFTEST FAILED: %d check(s) failed: %s" % (len(failures), ", ".join(failures)))
        return 1
    print("SELFTEST PASSED")
    return 0


def _iter_jsonl(path):
    fh = sys.stdin if path == "-" else open(path, "r")
    try:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                sys.stderr.write("reply_score: skipping bad JSON on line %d: %s\n" % (lineno, exc))
                continue
            yield lineno, row
    finally:
        if fh is not sys.stdin:
            fh.close()


def _rescore_jsonl(path, verbose):
    total = 0.0
    n = 0
    for lineno, row in _iter_jsonl(path):
        prior = row.get("prior", row.get("prior_context", ""))
        golden = row.get("golden", row.get("golden_reply", ""))
        suggestion = row.get("suggestion", "")
        s = score(prior, golden, suggestion)
        total += s
        n += 1
        if verbose:
            print("%.4f\tline=%d\tsuggestion=%r" % (s, lineno, suggestion))
    if n == 0:
        print("no rows scored")
        return 1
    print("backend: %s" % scoring_backend())
    print("rows: %d" % n)
    print("mean score: %.4f" % (total / n))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--selftest", action="store_true", help="run built-in assertions and exit")
    parser.add_argument("--jsonl", metavar="PATH", help="re-score a JSONL file of {prior,golden,suggestion} rows ('-' for stdin)")
    parser.add_argument("--verbose", action="store_true", help="with --jsonl, print each row's score")
    parser.add_argument("--prior", default="", help="ad-hoc single scoring: prior context")
    parser.add_argument("--golden", default="", help="ad-hoc single scoring: golden reply")
    parser.add_argument("--suggestion", default="", help="ad-hoc single scoring: suggestion to score")
    args = parser.parse_args()

    if args.selftest:
        sys.exit(_selftest())

    if args.jsonl:
        sys.exit(_rescore_jsonl(args.jsonl, args.verbose))

    if args.suggestion or args.golden:
        s = score(args.prior, args.golden, args.suggestion)
        print("%.4f" % s)
        sys.exit(0)

    parser.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()
