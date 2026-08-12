#!/usr/bin/env python3
"""Aggregate-only historical discovery for Tilde Personal Brain recipes."""
import argparse, csv, datetime, hashlib, io, json, math, os, stat, subprocess, tempfile, unicodedata
from pathlib import Path
SCHEMA = "tilde.personal-brain-historical-discovery.v1"
LABEL = "historical_discovery"
STATUS_FILE = "status.json"
RESULTS_FILE = "recipe-results.tsv"
SESSION_GAP_SECONDS = 30 * 60
DAY_SECONDS = 24 * 60 * 60
CONTEXT_LIMITS = (0, 1, 2, 4)
HORIZONS = (("30", 30), ("90", 90), ("365", 365), ("all", None))
SCOPES = ("global", "chat-then-global")
SUPPORTS = (1, 2, 3, 5)
SHARES = (("0", 0, 1), ("0.25", 1, 4), ("0.5", 1, 2), ("0.75", 3, 4))
RATIOS = (("1", 1, 1), ("1.5", 3, 2), ("2", 2, 1), ("4", 4, 1))
RECIPE_COUNT = len(CONTEXT_LIMITS) * len(HORIZONS) * len(SCOPES) * len(SUPPORTS) * len(SHARES) * len(RATIOS)
REASONS = {
    None, "database_unreadable", "database_schema_invalid", "database_query_failed",
    "source_unreadable", "source_invalid",
    "invalid_run_directory", "artifact_write_failed", "insufficient_session_groups",
    "insufficient_token_volume", "empty_screen_after_duplicate_exclusion",
    "no_strict_chronological_split", "status_unavailable", "status_invalid",
    "unexpected_failure",
}
STATUS_KEYS = {
    "schema", "label", "state", "incomplete", "invalid", "reason", "privacy",
    "source_counts", "split", "recipes", "representatives",
}
GATE_MASK_CACHE = {}
class SafeFailure(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason
class Message:
    __slots__ = ("timestamp", "chat", "session", "text", "tokens")
    def __init__(self, timestamp, chat, text, session=None):
        self.timestamp = timestamp
        self.chat = chat
        self.session = chat if session is None else session
        self.text = text
        self.tokens = letter_tokens(text)
class Session:
    __slots__ = ("chat", "first", "last", "messages")
    def __init__(self, message):
        self.chat = message.session
        self.first = message.timestamp
        self.last = message.timestamp
        self.messages = [message]
class Bag:
    """Incremental counts with deterministic O(1) winner/runner lookup."""
    __slots__ = ("counts", "total", "top", "runner")
    def __init__(self):
        self.counts = {}
        self.total = 0
        self.top = None
        self.runner = None
    def add(self, token):
        self.counts[token] = self.counts.get(token, 0) + 1
        self.total += 1
        choices = {value for value in (self.top, self.runner, token) if value is not None}
        ranked = sorted(choices, key=lambda value: (-self.counts[value], value))
        self.top = ranked[0]
        self.runner = ranked[1] if len(ranked) > 1 else None
    def winner(self):
        if self.top is None:
            return None
        return (
            self.top,
            self.counts[self.top],
            self.counts[self.runner] if self.runner is not None else 0,
            self.total,
        )
class CountEngine:
    """One shared count engine serving the complete bounded recipe grid."""
    def __init__(self):
        self.global_bags = {name: [dict() for _ in range(5)] for name, _days in HORIZONS}
        self.chat_bags = {name: {} for name, _days in HORIZONS}
    @staticmethod
    def _add(index, context, target):
        bag = index.get(context)
        if bag is None:
            bag = Bag()
            index[context] = bag
        bag.add(target)
    def learn(self, prior, chat, target, horizon_names):
        contexts = [tuple()] + [context_key(prior[-size:]) for size in range(1, 5)]
        for horizon in horizon_names:
            chat_orders = self.chat_bags[horizon].setdefault(chat, [dict() for _ in range(5)])
            for order in range(5):
                if order > len(prior):
                    break
                self._add(self.global_bags[horizon][order], contexts[order], target)
                self._add(chat_orders[order], contexts[order], target)
    def profiles(self, prior, chat, target, horizon, scope):
        contexts = [tuple()] + [context_key(prior[-size:]) for size in range(1, 5)]
        chat_orders = self.chat_bags[horizon].get(chat)
        order_candidates = []
        for order in range(5):
            if order > len(prior):
                order_candidates.append([])
                continue
            context = contexts[order]
            global_bag = self.global_bags[horizon][order].get(context)
            chat_bag = chat_orders[order].get(context) if chat_orders is not None else None
            candidates = [global_bag] if scope == "global" else [chat_bag, global_bag]
            order_candidates.append([bag for bag in candidates if bag is not None])
        cache = {}
        decisions = {}
        for maximum in CONTEXT_LIMITS:
            predicted = correct = 0
            for order in range(maximum, -1, -1):
                for bag in order_candidates[order]:
                    identity = id(bag)
                    if identity not in cache:
                        winner, support, runner, total = bag.winner()
                        support_level = sum(support >= threshold for threshold in SUPPORTS)
                        share_level = sum(support * denominator >= numerator * total for _label, numerator, denominator in SHARES)
                        ratio_level = sum(
                            runner == 0 or support * denominator >= numerator * runner
                            for _label, numerator, denominator in RATIOS
                        )
                        cache[identity] = (gate_mask(support_level, share_level, ratio_level), winner == target)
                    eligible, exact = cache[identity]
                    newly_selected = eligible & ~predicted
                    predicted |= newly_selected
                    if exact:
                        correct |= newly_selected
            decisions[maximum] = (predicted, correct)
        return decisions
# PRIVACY BOUNDARY: message text, tokens, predictions, contexts, and chat IDs
# exist only in memory. Only the fixed aggregate structures below may be written.
def letter_tokens(text):
    normalized = unicodedata.normalize("NFC", text)
    tokens = []
    current = []
    for character in normalized:
        if unicodedata.category(character).startswith("L"):
            current.append(character)
        else:
            append_token(tokens, current)
            current = []
    append_token(tokens, current)
    return tokens
def append_token(tokens, characters):
    if not characters:
        return
    token = unicodedata.normalize("NFC", "".join(characters))
    if 1 <= len(token) <= 30:
        tokens.append(token)
def folded(text):
    return unicodedata.normalize("NFC", text.casefold())
def context_key(tokens):
    return tuple(folded(token) for token in tokens)
def message_key(tokens):
    return context_key(tokens)
def gate_mask(support_level, share_level, ratio_level):
    levels = (support_level, share_level, ratio_level)
    cached = GATE_MASK_CACHE.get(levels)
    if cached is not None:
        return cached
    mask = 0
    for support in range(support_level):
        for share in range(share_level):
            for ratio_index in range(ratio_level):
                bit = (support * len(SHARES) + share) * len(RATIOS) + ratio_index
                mask |= 1 << bit
    GATE_MASK_CACHE[levels] = mask
    return mask
def apple_seconds(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise ValueError
    if abs(result) >= 1_000_000_000_000:
        result /= 1_000_000_000
    return result
def load_messages(database, cutoff):
    try:
        source = Path(database)
        metadata = source.lstat()
        if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
            raise SafeFailure("database_unreadable")
        read_fd, write_fd = os.pipe()
        helper = Path(__file__).with_name("personal_brain_messages.swift")
        process = subprocess.Popen(
            ["xcrun", "swift", str(helper), "--stream-fd", str(write_fd), str(source.resolve()), str(cutoff)],
            pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        os.close(write_fd)
    except (OSError, subprocess.SubprocessError) as exc:
        raise SafeFailure("database_unreadable") from exc
    messages = []
    summary = None
    invalid_dates = 0
    try:
        with os.fdopen(read_fd, "r", encoding="utf-8") as stream:
            for line in stream:
                record = json.loads(line)
                if record.get("kind") == "summary":
                    summary = record
                    continue
                if set(record) != {"kind", "timestamp", "chat", "text", "source"}:
                    raise SafeFailure("database_query_failed")
                date_value, text, chat = record["timestamp"], record["text"], record["chat"]
                if not isinstance(text, str) or not isinstance(chat, int):
                    raise SafeFailure("database_query_failed")
                try:
                    timestamp = apple_seconds(date_value)
                except ValueError:
                    invalid_dates += 1
                    continue
                messages.append(Message(timestamp, chat, text))
        if process.wait() != 0 or summary is None:
            raise SafeFailure("database_query_failed")
        if (
            len(summary.get("selection_digest", "")) != 64
            or summary["selected_clean_rows"] != summary["text_rows"] + summary["attributed_body_rows"]
            or summary["attributed_body_candidates"]
            != summary["attributed_body_rows"] + summary["attributed_body_decode_failures"]
            or summary["selected_clean_rows"] != len(messages) + invalid_dates
        ):
            raise SafeFailure("database_query_failed")
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        process.kill()
        process.wait()
        raise SafeFailure("database_query_failed") from exc
    except SafeFailure:
        process.kill()
        process.wait()
        raise
    messages.sort(key=lambda message: message.timestamp)
    return messages, {
        "source_kind": "messages",
        "source_cutoff_apple_seconds": cutoff,
        "selected_clean_rows": summary["selected_clean_rows"],
        "selection_digest": summary["selection_digest"],
        "text_rows": summary["text_rows"],
        "attributed_body_candidates": summary["attributed_body_candidates"],
        "attributed_body_rows": summary["attributed_body_rows"],
        "attributed_body_decode_failures": summary["attributed_body_decode_failures"],
        "invalid_date_messages": invalid_dates,
    }
def rfc3339_seconds(value):
    if not isinstance(value, str) or not 1 <= len(value) <= 64:
        raise ValueError
    try:
        parsed = datetime.datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
    except ValueError as exc:
        raise ValueError from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError
    result = parsed.timestamp()
    if not math.isfinite(result) or result <= 0:
        raise ValueError
    return result
def regular_file(path):
    try:
        metadata = path.lstat()
        return stat.S_ISREG(metadata.st_mode) and not stat.S_ISLNK(metadata.st_mode)
    except OSError:
        return False
def require_source_directory(path):
    try: metadata = path.lstat()
    except OSError as exc: raise SafeFailure("source_unreadable") from exc
    if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or not os.access(path, os.R_OK | os.X_OK):
        raise SafeFailure("source_unreadable")
def source_digest(identities):
    digest = hashlib.sha256()
    for identity in sorted(identities):
        digest.update(identity.encode("utf-8"))
        digest.update(b"\n")
    return digest.hexdigest()
def load_codex(root, cutoff):
    try:
        cutoff = float(cutoff)
        if not math.isfinite(cutoff) or cutoff <= 0:
            raise ValueError
    except (TypeError, ValueError) as exc:
        raise SafeFailure("source_invalid") from exc
    root = Path(root)
    require_source_directory(root)
    candidates = sorted(
        list((root / "sessions").glob("**/rollout-*.jsonl"))
        + list((root / "archived_sessions").glob("**/rollout-*.jsonl"))
    )
    counts = {"source_kind": "codex", "files_considered": len(candidates), "files_accepted": 0,
              "files_rejected": 0, "records_seen": 0, "records_accepted": 0,
              "duplicate_records_excluded": 0, "malformed_tail_files": 0,
              "source_cutoff_unix_seconds": cutoff, "input_mode": "unknown"}
    messages, seen, identities = [], set(), []
    for path in candidates:
        if not regular_file(path):
            counts["files_rejected"] += 1
            continue
        try:
            with path.open("rb") as handle:
                first = handle.readline(65_537)
                if len(first) > 65_536: raise SafeFailure("source_invalid")
                if not first.endswith(b"\n"): counts["files_rejected"] += 1; counts["malformed_tail_files"] += 1; continue
                meta = json.loads(first.decode("utf-8"))
                payload = meta.get("payload") if isinstance(meta, dict) and meta.get("type") == "session_meta" else None
                session_id = payload.get("id") if isinstance(payload, dict) else None
                allowed = (
                    isinstance(session_id, str) and 1 <= len(session_id) <= 128
                    and payload.get("thread_source") == "user" and payload.get("source") in {"vscode", "cli"}
                )
                if not allowed:
                    counts["files_rejected"] += 1
                    continue  # Do not decode excluded bodies.
                counts["files_accepted"] += 1
                while True:
                    raw = handle.readline(33_554_433)
                    if not raw:
                        break
                    if len(raw) > 33_554_432:
                        raise SafeFailure("source_invalid")
                    counts["records_seen"] += 1
                    try:
                        record = json.loads(raw.decode("utf-8"))
                    except (UnicodeError, json.JSONDecodeError) as exc:
                        if not raw.endswith(b"\n"):
                            counts["malformed_tail_files"] += 1
                            break
                        raise SafeFailure("source_invalid") from exc
                    event = record.get("payload") if isinstance(record, dict) and record.get("type") == "event_msg" else None
                    if not isinstance(event, dict) or event.get("type") != "user_message":
                        continue
                    text, raw_timestamp = event.get("message"), record.get("timestamp")
                    try:
                        timestamp = rfc3339_seconds(raw_timestamp)
                    except ValueError as exc:
                        raise SafeFailure("source_invalid") from exc
                    if timestamp > cutoff:
                        continue
                    if not isinstance(text, str):
                        raise SafeFailure("source_invalid")
                    if len(raw) > 2_097_152:
                        raise SafeFailure("source_invalid")
                    normalized = unicodedata.normalize("NFC", text)
                    identity = canonical_json([session_id, raw_timestamp, normalized])
                    if identity in seen:
                        counts["duplicate_records_excluded"] += 1
                        continue
                    seen.add(identity)
                    identities.append(identity)
                    messages.append(Message(timestamp, session_id, normalized))
                    counts["records_accepted"] += 1
        except SafeFailure:
            raise
        except OSError as exc:
            raise SafeFailure("source_unreadable") from exc
    messages.sort(key=lambda message: message.timestamp)
    counts.update({"selected_clean_rows": len(messages), "selection_digest": source_digest(identities),
                   "text_rows": len(messages), "invalid_date_messages": 0})
    return messages, counts
LEGACY_ROOTS = (
    "~/Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage",
    "~/Library/Application Support/Tilde/usage",
    "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage",
    "~/Library/Application Support/SteadyType/usage",
)
LEGACY_SOURCES = {"fast", "personal_word", "model", "model_memory", "policy"}
def load_legacy(roots=None):
    strict = roots is not None
    roots = [Path(value).expanduser() for value in (roots or LEGACY_ROOTS)]
    if strict:
        for root in roots: require_source_directory(root)
    else:
        roots = [root for root in roots if root.exists()]
        for root in roots: require_source_directory(root)
        if not roots: raise SafeFailure("source_unreadable")
    chosen, all_occurrences = {}, 0
    counts = {"source_kind": "legacy_typed_instead", "roots_considered": len(roots),
              "files_considered": 0, "files_rejected": 0, "records_seen": 0,
              "typed_instead_candidates": 0, "records_rejected": 0}
    for root in roots:
        per_root = {}
        for path in sorted(root.glob("ghost_events_*.jsonl")):
            counts["files_considered"] += 1
            if not regular_file(path):
                counts["files_rejected"] += 1
                continue
            try:
                with path.open("r", encoding="utf-8") as handle:
                    for line in handle:
                        counts["records_seen"] += 1
                        try:
                            event = json.loads(line)
                        except json.JSONDecodeError as exc:
                            raise SafeFailure("source_invalid") from exc
                        if not isinstance(event, dict) or event.get("event") != "typed_instead":
                            continue
                        counts["typed_instead_candidates"] += 1
                        context, typed = event.get("context"), event.get("typed")
                        app, source, ghost, ghost_len = (
                            event.get("app_bundle"), event.get("source"), event.get("ghost"), event.get("ghost_len")
                        )
                        valid = (
                            isinstance(context, str) and bool(context.strip()) and isinstance(typed, str) and bool(typed.strip())
                            and isinstance(app, str) and 1 <= len(app) <= 255 and source in LEGACY_SOURCES
                            and isinstance(ghost, str) and bool(ghost) and isinstance(ghost_len, int)
                            and not isinstance(ghost_len, bool) and ghost_len == len(unicodedata.normalize("NFC", ghost)) and len(letter_tokens(typed)) >= 2
                        )
                        try:
                            timestamp = rfc3339_seconds(event.get("ts"))
                        except ValueError:
                            valid = False
                        if not valid:
                            counts["records_rejected"] += 1
                            continue
                        canonical = canonical_json(event)
                        identity = canonical_json([path.name, canonical])
                        per_root.setdefault(identity, []).append(Message(timestamp, app, typed, path.name))
            except SafeFailure:
                raise
            except (OSError, UnicodeError) as exc:
                raise SafeFailure("source_unreadable") from exc
        for identity, occurrences in per_root.items():
            all_occurrences += len(occurrences)
            if len(occurrences) > len(chosen.get(identity, ())):
                chosen[identity] = occurrences
    messages = [message for identity in sorted(chosen) for message in chosen[identity]]
    messages.sort(key=lambda message: message.timestamp)
    identities = [identity for identity in sorted(chosen) for _message in chosen[identity]]
    counts.update({"selected_clean_rows": len(messages), "records_accepted": len(messages),
                   "mirror_records_excluded": all_occurrences - len(messages),
                   "selection_digest": source_digest(identities), "text_rows": len(messages),
                   "invalid_date_messages": 0})
    return messages, counts
def sessions_for(messages):
    active = {}
    sessions = []
    for message in messages:
        session = active.get(message.session)
        if session is None or message.timestamp - session.last > SESSION_GAP_SECONDS:
            session = Session(message)
            active[message.session] = session
            sessions.append(session)
        else:
            session.messages.append(message)
            session.last = message.timestamp
    return sorted(sessions, key=lambda session: session.first)
def chronological_blocks(sessions):
    blocks = []
    for session in sorted(sessions, key=lambda item: item.first):
        if not blocks or session.first > blocks[-1][1]:
            blocks.append(([session], session.last))
        else:
            blocks[-1][0].append(session)
            blocks[-1] = (blocks[-1][0], max(blocks[-1][1], session.last))
    return blocks
def split_sessions(sessions):
    blocks = chronological_blocks(sessions)
    if len(blocks) < 4:
        return None
    volumes = [
        sum(len(message.tokens) for session in block for message in session.messages)
        for block, _last in blocks
    ]
    total = sum(volumes)
    if total == 0:
        return None
    prefix = [0]
    for volume in volumes:
        prefix.append(prefix[-1] + volume)
    boundaries = []
    previous = 0
    for target, remaining in ((7, 3), (8, 2), (9, 1)):
        candidates = range(previous + 1, len(blocks) - remaining + 1)
        boundary = min(candidates, key=lambda index: (abs(prefix[index] * 10 - total * target), index), default=None)
        if boundary is None:
            return None
        boundaries.append(boundary)
        previous = boundary
    first, second, third = boundaries
    actual = (prefix[first], prefix[second] - prefix[first], prefix[third] - prefix[second], total - prefix[third])
    if min(actual) == 0:
        return None
    groups = (blocks[:first], blocks[first:second], blocks[second:third], blocks[third:])
    result = tuple([session for block, _last in group for session in block] for group in groups)
    for earlier, later in zip(result, result[1:]):
        assert max(session.last for session in earlier) < min(session.first for session in later)
    return result
def messages_in(sessions):
    return [message for session in sessions for message in session.messages]
def base_status(state, reason, source_counts=None, split=None):
    source = {
        "source_kind": "unknown",
        "selected_clean_rows": 0,
        "selection_digest": "",
        "text_rows": 0,
        "attributed_body_candidates": 0,
        "attributed_body_rows": 0,
        "attributed_body_decode_failures": 0,
        "invalid_date_messages": 0,
        "source_cutoff_apple_seconds": 0,
        "messages_with_letter_tokens": 0,
        "letter_tokens": 0,
        "duplicate_screen_messages_excluded": 0,
        "duplicate_screen_tokens_excluded": 0,
    }
    source.update(source_counts or {})
    split_counts = {
        "sessions": 0,
        "train_sessions": 0,
        "screen_sessions": 0,
        "screen_sessions_retained": 0,
        "train_messages": 0,
        "screen_messages_before_duplicate_exclusion": 0,
        "screen_messages": 0,
        "train_tokens": 0,
        "screen_tokens_before_duplicate_exclusion": 0,
        "screen_tokens": 0,
        "screen_opportunities": 0,
        "historical_validation_sessions": 0,
        "historical_validation_messages": 0,
        "historical_validation_tokens": 0,
        "historical_vault_sessions": 0,
        "historical_vault_messages": 0,
        "historical_vault_tokens": 0,
    }
    split_counts.update(split or {})
    return {
        "schema": SCHEMA,
        "label": LABEL,
        "state": state,
        "incomplete": state == "incomplete",
        "invalid": state == "invalid",
        "reason": reason,
        "privacy": {
            "aggregate_only": True,
            "raw_text_persisted": False,
            "source_paths_persisted": False,
            "candidates_persisted": False,
            "contexts_or_targets_persisted": False,
            "app_or_chat_ids_persisted": False,
            "per_case_ids_or_hashes_persisted": False,
            "aggregate_selection_digest": True,
            "undecodable_bodies_are_censored": True,
            "token_metrics_are_not_ui_offers": True,
            "database_read_only": True,
            "run_dir_owner_only": True,
            "atomic_writes": True,
        },
        "source_counts": source,
        "split": split_counts,
        "recipes": {"count": RECIPE_COUNT, "opportunities_per_recipe": split_counts["screen_opportunities"], "results_digest": None},
        "representatives": None,
    }
def evaluate(train_messages, screen_messages, screen_start):
    engine = CountEngine()
    all_horizons = tuple(name for name, _days in HORIZONS)
    for message in sorted(train_messages, key=lambda item: item.timestamp):
        age = max(0.0, screen_start - message.timestamp)
        horizons = tuple(name for name, days in HORIZONS if days is None or age <= days * DAY_SECONDS)
        prior = []
        for target in message.tokens:
            engine.learn(prior, message.chat, target, horizons)
            prior.append(target)
    histograms = {
        (horizon, maximum, scope): {}
        for horizon in all_horizons
        for maximum in CONTEXT_LIMITS
        for scope in SCOPES
    }
    opportunities = 0
    for message in sorted(screen_messages, key=lambda item: item.timestamp):
        prior = []
        for position, target in enumerate(message.tokens):
            if position:
                opportunities += 1
                for horizon in all_horizons:
                    for scope in SCOPES:
                        decisions = engine.profiles(prior, message.chat, target, horizon, scope)
                        for maximum, decision in decisions.items():
                            histogram = histograms[(horizon, maximum, scope)]
                            histogram[decision] = histogram.get(decision, 0) + 1
            # Prediction for every recipe is recorded before this target is learned.
            engine.learn(prior, message.chat, target, all_horizons)
            prior.append(target)
    return recipe_results(histograms, opportunities), histograms
def ratio(count, denominator):
    return round(count / denominator, 6) if denominator else 0.0
def recipe_results(histograms, opportunities):
    results = []
    number = 0
    for maximum in CONTEXT_LIMITS:
        for horizon, _days in HORIZONS:
            for scope in SCOPES:
                histogram = histograms[(horizon, maximum, scope)]
                for support_index, support in enumerate(SUPPORTS):
                    for share_index, (share, _numerator, _denominator) in enumerate(SHARES):
                        for ratio_index, (top_ratio, _numerator, _denominator) in enumerate(RATIOS):
                            number += 1
                            predictions = exact_hits = 0
                            bit = 1 << ((support_index * len(SHARES) + share_index) * len(RATIOS) + ratio_index)
                            for (predicted_mask, correct_mask), count in histogram.items():
                                if predicted_mask & bit:
                                    predictions += count
                                if correct_mask & bit:
                                    exact_hits += count
                            wrong = predictions - exact_hits
                            results.append(
                                {
                                    "recipe_id": f"r{number:04d}",
                                    "max_context": maximum,
                                    "seed_history_horizon_days": horizon,
                                    "scope": scope,
                                    "minimum_winner_support": support,
                                    "minimum_top_share": share,
                                    "minimum_top_runner_ratio": top_ratio,
                                    "opportunities": opportunities,
                                    "token_exact_hits": exact_hits,
                                    "token_exact_hit_rate": ratio(exact_hits, opportunities),
                                    "token_predictions": predictions,
                                    "token_precision": ratio(exact_hits, predictions),
                                    "token_coverage": ratio(predictions, opportunities),
                                    "token_misses": wrong,
                                }
                            )
    if len(results) != RECIPE_COUNT:
        raise AssertionError("recipe grid size changed")
    return results
def results_tsv(results):
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=list(results[0]), delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(results)
    return output.getvalue()
def recipe_id(maximum, horizon, scope, support, share, top_ratio):
    number = 0
    for candidate_maximum in CONTEXT_LIMITS:
        for candidate_horizon, _days in HORIZONS:
            for candidate_scope in SCOPES:
                for candidate_support in SUPPORTS:
                    for candidate_share, _numerator, _denominator in SHARES:
                        for candidate_ratio, _numerator, _denominator in RATIOS:
                            number += 1
                            if (candidate_maximum, candidate_horizon, candidate_scope, candidate_support,
                                candidate_share, candidate_ratio) == (maximum, horizon, scope, support, share, top_ratio):
                                return f"r{number:04d}"
    raise AssertionError("unknown recipe")
def summary_result(result):
    return {key: result[key] for key in result if key != "opportunities"} | {"opportunities": result["opportunities"]}
def discover(messages, loaded_counts=None):
    source = dict(loaded_counts or {})
    source.setdefault("selected_clean_rows", len(messages))
    source.setdefault("text_rows", len(messages))
    source.setdefault("attributed_body_rows", 0)
    source.setdefault("attributed_body_decode_failures", 0)
    source.setdefault("invalid_date_messages", 0)
    source["messages_with_letter_tokens"] = sum(bool(message.tokens) for message in messages)
    source["letter_tokens"] = sum(len(message.tokens) for message in messages)
    sessions = sessions_for(messages)
    split = {"sessions": len(sessions)}
    partition = split_sessions(sessions)
    if partition is None:
        if len(sessions) < 4:
            reason = "insufficient_session_groups"
        elif len(chronological_blocks(sessions)) < 4:
            reason = "no_strict_chronological_split"
        else:
            reason = "insufficient_token_volume"
        status = base_status("incomplete", reason, source, split)
        return status, "", None
    train_sessions, screen_sessions, validation_sessions, vault_sessions = partition
    train = messages_in(train_sessions)
    screen_before = messages_in(screen_sessions)
    validation = messages_in(validation_sessions)
    vault = messages_in(vault_sessions)
    train_text = {message_key(message.tokens) for message in train}
    screen = [message for message in screen_before if message_key(message.tokens) not in train_text]
    excluded = [message for message in screen_before if message_key(message.tokens) in train_text]
    source["duplicate_screen_messages_excluded"] = len(excluded)
    source["duplicate_screen_tokens_excluded"] = sum(len(message.tokens) for message in excluded)
    retained_session_count = sum(
        any(message_key(message.tokens) not in train_text for message in session.messages)
        for session in screen_sessions
    )
    split.update(
        {
            "train_sessions": len(train_sessions),
            "screen_sessions": len(screen_sessions),
            "screen_sessions_retained": retained_session_count,
            "train_messages": len(train),
            "screen_messages_before_duplicate_exclusion": len(screen_before),
            "screen_messages": len(screen),
            "train_tokens": sum(len(message.tokens) for message in train),
            "screen_tokens_before_duplicate_exclusion": sum(len(message.tokens) for message in screen_before),
            "screen_tokens": sum(len(message.tokens) for message in screen),
            "screen_opportunities": sum(max(0, len(message.tokens) - 1) for message in screen),
            "historical_validation_sessions": len(validation_sessions),
            "historical_validation_messages": len(validation),
            "historical_validation_tokens": sum(len(message.tokens) for message in validation),
            "historical_vault_sessions": len(vault_sessions),
            "historical_vault_messages": len(vault),
            "historical_vault_tokens": sum(len(message.tokens) for message in vault),
        }
    )
    if split["screen_opportunities"] == 0:
        status = base_status("incomplete", "empty_screen_after_duplicate_exclusion", source, split)
        return status, "", None
    results, histograms = evaluate(train, screen, min(message.timestamp for message in screen_before))
    status = base_status("complete", None, source, split)
    by_id = {row["recipe_id"]: row for row in results}
    exploratory = max(results, key=lambda row: (row["token_exact_hits"], -row["token_misses"], row["token_precision"], -int(row["recipe_id"][1:])))
    status["representatives"] = {
        "exploratory_max_hits": summary_result(exploratory),
        "predeclared_quiet": summary_result(by_id[recipe_id(2, "365", "chat-then-global", 5, "0.75", "4")]),
        "predeclared_balanced": summary_result(by_id[recipe_id(2, "365", "chat-then-global", 2, "0.5", "2")]),
    }
    return status, results_tsv(results), histograms
def validate_run_dir(run_dir, create):
    path = Path(run_dir)
    try:
        if create:
            path.mkdir(mode=0o700)
        metadata = path.lstat()
    except FileExistsError:
        try:
            metadata = path.lstat()
        except OSError as exc:
            raise SafeFailure("invalid_run_directory") from exc
    except OSError as exc:
        raise SafeFailure("invalid_run_directory") from exc
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or stat.S_ISLNK(metadata.st_mode)
        or metadata.st_uid != os.getuid()
        or stat.S_IMODE(metadata.st_mode) & 0o077
    ):
        raise SafeFailure("invalid_run_directory")
    return path
def atomic_write(run_dir, name, content):
    descriptor = None
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=".personal-brain-", dir=run_dir)
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            descriptor = None
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, run_dir / name)
        temporary = None
        directory_fd = os.open(run_dir, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except OSError as exc:
        raise SafeFailure("artifact_write_failed") from exc
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if temporary is not None:
            try:
                os.unlink(temporary)
            except OSError:
                pass
def canonical_json(payload):
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
def execute_run(run_dir, load_source):
    directory = validate_run_dir(run_dir, create=True)
    if (directory / RESULTS_FILE).exists():
        raise SafeFailure("invalid_run_directory")
    try:
        reservation = os.open(directory / STATUS_FILE, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        os.close(reservation)
    except OSError as exc: raise SafeFailure("invalid_run_directory") from exc
    try:
        messages, source_counts = load_source()
        status, tsv, _histograms = discover(messages, source_counts)
        if status["state"] == "complete":
            status["recipes"]["results_digest"] = hashlib.sha256(tsv.encode()).hexdigest()
            atomic_write(directory, RESULTS_FILE, tsv)
        atomic_write(directory, STATUS_FILE, canonical_json(status) + "\n")
        return (0 if status["state"] == "complete" else 1), status
    except SafeFailure as failure:
        status = base_status("invalid", failure.reason)
        atomic_write(directory, STATUS_FILE, canonical_json(status) + "\n")
        return 2, status
def valid_status(payload):
    if not isinstance(payload, dict) or set(payload) != STATUS_KEYS:
        return False
    state, source, split, recipes = (payload.get(key) for key in ("state", "source_counts", "split", "recipes"))
    if not all(isinstance(value, dict) for value in (source, split, recipes)):
        return False
    reason, representatives = payload.get("reason"), payload.get("representatives")
    base = base_status(state, reason)
    extras = {
        "unknown": set(), "messages": set(),
        "codex": {"files_considered", "files_accepted", "files_rejected", "records_seen", "records_accepted", "duplicate_records_excluded", "malformed_tail_files", "source_cutoff_unix_seconds", "input_mode"},
        "legacy_typed_instead": {"roots_considered", "files_considered", "files_rejected", "records_seen", "typed_instead_candidates", "records_rejected", "records_accepted", "mirror_records_excluded"},
    }
    incomplete_reasons = {"insufficient_session_groups", "insufficient_token_volume", "empty_screen_after_duplicate_exclusion", "no_strict_chronological_split"}
    reason_valid = ((state == "complete" and reason is None) or (state == "incomplete" and reason in incomplete_reasons) or (state == "invalid" and reason in REASONS - incomplete_reasons - {None}))
    text_source = {"selection_digest", "source_kind", "input_mode", "source_cutoff_apple_seconds", "source_cutoff_unix_seconds"}
    numeric_source = {key: value for key, value in source.items() if key not in text_source}
    kind = source.get("source_kind")
    apple, unix = source.get("source_cutoff_apple_seconds"), source.get("source_cutoff_unix_seconds")
    apple_number, unix_number = type(apple) in {int, float}, type(unix) in {int, float}
    cutoff_valid = ((kind == "messages" and apple_number and math.isfinite(apple) and apple > 0 and unix is None) or (kind == "codex" and apple == 0 and unix_number and math.isfinite(unix) and unix > 0) or (kind in {"legacy_typed_instead", "unknown"} and apple == 0 and unix is None))
    if not (
        payload.get("schema") == SCHEMA and payload.get("label") == LABEL and reason_valid
        and kind in extras and (kind != "unknown" or state == "invalid") and cutoff_valid
        and set(source) == set(base["source_counts"]) | extras[kind] and set(split) == set(base["split"])
        and set(recipes) == {"count", "opportunities_per_recipe", "results_digest"}
        and payload.get("privacy") == base["privacy"]
        and source.get("input_mode", "unknown") == "unknown"
        and payload.get("incomplete") is (state == "incomplete") and payload.get("invalid") is (state == "invalid")
        and all(type(value) is int and value >= 0 for value in (*numeric_source.values(), *split.values()))
        and isinstance(source.get("selection_digest"), str) and len(source["selection_digest"]) in ({64} if state == "complete" else {0, 64}) and all(character in "0123456789abcdef" for character in source["selection_digest"])
        and recipes.get("count") == RECIPE_COUNT and recipes.get("opportunities_per_recipe") == split.get("screen_opportunities")
        and (representatives is None) == (state != "complete")
    ):
        return False
    if state != "complete":
        return recipes.get("results_digest") is None
    if len(recipes.get("results_digest", "")) != 64 or any(character not in "0123456789abcdef" for character in recipes["results_digest"]) or set(representatives) != {"exploratory_max_hits", "predeclared_quiet", "predeclared_balanced"}:
        return False
    for row in representatives.values():
        if not (all(type(value) in {int, float} and math.isfinite(value) for key, value in row.items() if key.startswith("token_") or key == "opportunities") and row["opportunities"] == split["screen_opportunities"] and row["token_exact_hits"] <= row["token_predictions"] <= row["opportunities"] and row["token_misses"] == row["token_predictions"] - row["token_exact_hits"]):
            return False
    return True
def read_status(run_dir):
    directory = validate_run_dir(run_dir, create=False)
    path = directory / STATUS_FILE
    try:
        metadata = path.lstat()
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) & 0o077:
            raise SafeFailure("status_invalid")
        payload = json.loads(path.read_text(encoding="utf-8"))
    except SafeFailure:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SafeFailure("status_unavailable") from exc
    if not valid_status(payload):
        raise SafeFailure("status_invalid")
    results = directory / RESULTS_FILE
    if payload["state"] == "complete":
        try:
            metadata = results.lstat()
            data = results.read_bytes()
        except OSError as exc:
            raise SafeFailure("status_invalid") from exc
        if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) & 0o077 or hashlib.sha256(data).hexdigest() != payload["recipes"]["results_digest"]:
            raise SafeFailure("status_invalid")
    elif results.exists():
        raise SafeFailure("status_invalid")
    return payload
def source_selftest():
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        def emit(path, *records, tail=b""):
            path.parent.mkdir(parents=True, exist_ok=True)
            body = b"".join((canonical_json(record) + "\n").encode() for record in records) + tail
            path.write_bytes(body)
        meta = {"type": "session_meta", "payload": {"id": "client-one", "thread_source": "user", "source": "cli"}}
        wide_meta = meta | {"payload": meta["payload"] | {"cwd": "x" * 17_000}}
        user = {"timestamp": "2026-01-01T00:00:00.123Z", "type": "event_msg", "payload": {"type": "user_message", "message": "RAW_CODEX_SENTINEL alpha beta " + "x" * 1_300_000}}
        ignored = {"timestamp": "2026-01-01T00:00:01Z", "type": "event_msg", "payload": {"type": "tool_message", "message": "ignored"}}
        large_ignored = {"type": "response_item", "content": "x" * 1_100_000}
        active = root / "codex/sessions/2026/01/rollout-good.jsonl"
        emit(active, wide_meta, ignored, large_ignored, {"type": "response_item", "role": "user", "content": "ignored"}, user, tail=b"{malformed tail")
        denied = root / "codex/sessions/2026/01/rollout-denied.jsonl"; emit(denied, {"type": "session_meta", "payload": {"thread_source": "user", "source": "cli"}}, tail=b"\xff"); emit(root / "codex/sessions/2026/01/rollout-incomplete.jsonl", tail=b'{"type":"session_meta"')
        emit(root / "codex/archived_sessions/rollout-copy.jsonl", meta, user)
        codex, cc = load_codex(root / "codex", 2_000_000_000)
        assert len(codex) == 1 and cc["duplicate_records_excluded"] == 1 and cc["files_rejected"] == 2 and cc["malformed_tail_files"] == 2 and valid_status(base_status("incomplete", "insufficient_session_groups", cc)) and not valid_status(base_status("invalid", None)); bad = base_status("incomplete", "insufficient_session_groups", cc); bad["source_counts"]["source_cutoff_unix_seconds"] = float("nan"); assert not valid_status(bad); bad["source_counts"]["source_cutoff_unix_seconds"] = 1; bad["source_counts"]["extra"] = 0; assert not valid_status(bad)
        assert "raw_codex_sentinel" not in canonical_json(cc).lower()
        bad_codex = root / "bad-codex/sessions/rollout-bad.jsonl"; emit(bad_codex, meta, tail=b"{bad}\n")
        try: load_codex(root / "bad-codex", 2_000_000_000); raise AssertionError("malformed Codex record accepted")
        except SafeFailure as failure: assert failure.reason == "source_invalid"
        huge_codex = root / "huge-codex/sessions/rollout-huge.jsonl"; emit(huge_codex, meta | {"padding": "x" * 65_536})
        try: load_codex(root / "huge-codex", 2_000_000_000); raise AssertionError("oversize Codex metadata accepted")
        except SafeFailure as failure: assert failure.reason == "source_invalid"
        future = root / "future/sessions/rollout-future.jsonl"; emit(future, meta, user | {"timestamp": "2099-01-01T00:00:00Z", "payload": user["payload"] | {"message": "x" * 2_100_000}}); assert load_codex(root / "future", 2_000_000_000)[0] == []; large_user = root / "large-user/sessions/rollout-large.jsonl"; emit(large_user, meta, user | {"payload": user["payload"] | {"message": "x" * 2_100_000}})
        try: load_codex(root / "large-user", 2_000_000_000); raise AssertionError("oversize Codex user message accepted")
        except SafeFailure as failure: assert failure.reason == "source_invalid"
        huge_line = root / "huge-line/sessions/rollout-huge.jsonl"; emit(huge_line, meta)
        with huge_line.open("r+b") as handle: handle.seek(0, os.SEEK_END); handle.seek(33_554_433, os.SEEK_CUR); handle.write(b"\n")
        try: load_codex(root / "huge-line", 2_000_000_000); raise AssertionError("32 MiB Codex line accepted")
        except SafeFailure as failure: assert failure.reason == "source_invalid"
        try: load_codex(root / "missing", 2_000_000_000); raise AssertionError("missing Codex root accepted")
        except SafeFailure as failure: assert failure.reason == "source_unreadable"
        legacy = {"ts": "2026-01-01T00:00:00+00:00", "event": "typed_instead", "context": "before cursor", "typed": "RAW_LEGACY_SENTINEL alpha beta", "app_bundle": "com.test.app", "source": "model", "ghost": "e\u0301", "ghost_len": 1}
        left, right = root / "left", root / "right"
        emit(left / "ghost_events_mac.jsonl", legacy, legacy, legacy | {"typed": "one"})
        emit(right / "ghost_events_mac.jsonl", legacy, legacy | {"source": "unknown"})
        outside = root / "private.jsonl"; emit(outside, legacy); (left / "ghost_events_link.jsonl").symlink_to(outside)
        one, lc = load_legacy([left, right]); two, lc2 = load_legacy([left, right])
        assert len(one) == 2 and lc["mirror_records_excluded"] == 1 and lc["files_rejected"] == 1 and valid_status(base_status("incomplete", "insufficient_session_groups", lc))
        assert one[0].session == "ghost_events_mac.jsonl" and one[0].chat == "com.test.app" and lc == lc2
        assert "raw_legacy_sentinel" not in canonical_json(lc).lower() and [m.timestamp for m in one] == [m.timestamp for m in two]
        bad_legacy = root / "bad-legacy"; emit(bad_legacy / "ghost_events_bad.jsonl", tail=b"{bad}\n")
        try: load_legacy([bad_legacy]); raise AssertionError("malformed legacy record accepted")
        except SafeFailure as failure: assert failure.reason == "source_invalid"
        try: load_legacy([root / "missing"]); raise AssertionError("missing legacy root accepted")
        except SafeFailure as failure: assert failure.reason == "source_unreadable"
        assert rfc3339_seconds("2026-01-01T00:00:00Z") == rfc3339_seconds("2026-01-01T01:00:00+01:00")
        try: rfc3339_seconds("2026-01-01T00:00:00"); raise AssertionError("timezone-free timestamp accepted")
        except ValueError: pass
        boundary = sessions_for([Message(1, "a", "one two"), Message(1 + SESSION_GAP_SECONDS, "a", "three four"), Message(2 + SESSION_GAP_SECONDS * 2, "a", "five six")])
        assert len(boundary) == 2
def selftest():
    source_selftest()
    hour = 60 * 60
    messages = [
        Message(1, "a", "RAW_SENTINEL alpha beta gamma delta epsilon zeta eta theta iota kappa lambda"),
        Message(hour, "b", "cross duplicate"),
        Message(2 * hour, "c", "CROSS, Duplicate"),
        Message(2 * hour + 10 * 60, "c", "novel tail"),
        Message(3 * hour, "d", "sealed validation"),
        Message(4 * hour, "e", "sealed vault"),
    ]
    receipt = {"source_cutoff_apple_seconds": 123.0, "selection_digest": "0" * 64}
    status_one, tsv_one, _histograms = discover(messages, receipt)
    status_two, tsv_two, _histograms = discover(messages, receipt)
    assert canonical_json(status_one) == canonical_json(status_two) and tsv_one == tsv_two
    split, source = status_one["split"], status_one["source_counts"]
    assert (split["sessions"], split["train_sessions"], split["screen_sessions"], split["historical_validation_sessions"], split["historical_vault_sessions"]) == (5, 2, 1, 1, 1)
    assert (source["duplicate_screen_messages_excluded"], source["source_cutoff_apple_seconds"], source["selection_digest"]) == (1, 123.0, "0" * 64)
    assert status_one["recipes"]["count"] == 2048 and len(tsv_one.splitlines()) == 2049
    assert status_one["recipes"]["opportunities_per_recipe"] == 1 and set(status_one["representatives"]) == {"exploratory_max_hits", "predeclared_quiet", "predeclared_balanced"}
    assert "sealed" not in tsv_one
    serialized = (canonical_json(status_one) + tsv_one).lower()
    assert "raw_sentinel" not in serialized and "/users/secret/chat.db" not in serialized
    decoder = subprocess.run(["xcrun", "swift", str(Path(__file__).with_name("personal_brain_messages.swift")), "--selftest"], capture_output=True, text=True, check=True)
    decoder_status = json.loads(decoder.stdout)
    assert (decoder_status["decoded_attributed_bodies"], decoder_status["attributed_body_candidates"], decoder_status["decoded_attributed_bodies"] + decoder_status["decode_failures"], decoder_status["selection_digest_selftest"]) == (2, 3, 3, True)
    assert decoder_status["raw_text_output"] is False and "raw_native_sentinel" not in decoder.stdout.lower()
    overlap = [
        Message(1, "a", "one two"), Message(20 * 60, "a", "three four"),
        Message(10 * 60, "b", "five six"), Message(25 * 60, "b", "seven eight"),
        Message(2 * hour, "c", "nine ten"), Message(3 * hour, "d", "eleven twelve"),
        Message(4 * hour, "e", "thirteen fourteen"), Message(5 * hour, "f", "fifteen sixteen"),
    ]
    groups = split_sessions(sessions_for(overlap))
    assert len(groups) == 4
    assert any({"a", "b"}.issubset({session.chat for session in group}) for group in groups)
    for earlier, later in zip(groups, groups[1:]):
        assert max(session.last for session in earlier) < min(session.first for session in later)
    def result_for(results, **wanted):
        return next(row for row in results if all(row[key] == value for key, value in wanted.items()))
    probe = Message(0, "probe", "echo echo")
    probe_results, _histograms = evaluate([], [probe], 0)
    loose = result_for(probe_results, max_context=0, seed_history_horizon_days="all", scope="global",
                       minimum_winner_support=1, minimum_top_share="0", minimum_top_runner_ratio="1")
    strict = result_for(probe_results, max_context=0, seed_history_horizon_days="all", scope="global",
                        minimum_winner_support=2, minimum_top_share="0", minimum_top_runner_ratio="1")
    assert loose["opportunities"] == 1 and loose["token_exact_hits"] == 1
    assert strict["token_predictions"] == 0
    backoff_results, _histograms = evaluate(
        [Message(1, "x", "cue rare"), Message(2, "x", "common common common")],
        [Message(10, "x", "cue common")], 10,
    )
    backoff = result_for(backoff_results, max_context=1, seed_history_horizon_days="all", scope="global",
                         minimum_winner_support=2, minimum_top_share="0", minimum_top_runner_ratio="1")
    assert backoff["token_predictions"] == 1 and backoff["token_exact_hits"] == 1
    case_results, _histograms = evaluate(
        [Message(1, "x", "Lead Hello Hello Hello")], [Message(10, "x", "lead hello")], 10,
    )
    case_miss = result_for(case_results, max_context=0, seed_history_horizon_days="all", scope="global",
                           minimum_winner_support=1, minimum_top_share="0", minimum_top_runner_ratio="1")
    assert case_miss["token_predictions"] == 1 and case_miss["token_exact_hits"] == 0
    context_results, _histograms = evaluate(
        [Message(1, "x", "Cue Finish"), Message(2, "x", "Cue Other")],
        [Message(10, "x", "cue Finish")], 10,
    )
    context_hit = result_for(context_results, max_context=1, seed_history_horizon_days="all", scope="global",
                             minimum_winner_support=1, minimum_top_share="0", minimum_top_runner_ratio="1")
    assert context_hit["token_exact_hits"] == 1
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        malformed = root / "private-source.db"
        malformed.write_bytes(b"RAW_SENTINEL not a database")
        run_dir = root / "run"
        run_dir.mkdir(mode=0o700)
        (run_dir / RESULTS_FILE).write_text("stale RAW_SENTINEL", encoding="utf-8")
        (run_dir / RESULTS_FILE).chmod(0o600)
        try: execute_run(run_dir, lambda: load_messages(malformed, 1)); raise AssertionError("run directory was reused")
        except SafeFailure as failure: assert failure.reason == "invalid_run_directory"
        assert (run_dir / RESULTS_FILE).read_text(encoding="utf-8") == "stale RAW_SENTINEL"
        fresh = root / "fresh"
        code, invalid = execute_run(fresh, lambda: load_messages(malformed, 1))
        assert code == 2 and invalid["state"] == "invalid"
        assert not (fresh / RESULTS_FILE).exists()
        persisted = (fresh / STATUS_FILE).read_text(encoding="utf-8").lower()
        assert "raw_sentinel" not in persisted and str(root).lower() not in persisted
        try: execute_run(fresh, lambda: ([], {})); raise AssertionError("reserved run directory was reused")
        except SafeFailure as failure: assert failure.reason == "invalid_run_directory"
        broad = root / "broad"
        broad.mkdir(mode=0o755)
        broad.chmod(0o755)
        try: validate_run_dir(broad, create=False); raise AssertionError("broad run directory accepted")
        except SafeFailure as failure: assert failure.reason == "invalid_run_directory"
    print("selftest OK: 2048 aggregate recipes, prequential holdout, and privacy boundary")
def public_failure(reason):
    return base_status("invalid", reason if reason in REASONS else "unexpected_failure")
def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Run aggregate-only Personal Brain historical discovery.")
    parser.add_argument("--selftest", action="store_true")
    subparsers = parser.add_subparsers(dest="command")
    run = subparsers.add_parser("run")
    sources = run.add_mutually_exclusive_group(required=True)
    sources.add_argument("--chat-db")
    sources.add_argument("--codex-root")
    sources.add_argument("--legacy-typed-instead", action="store_true")
    run.add_argument("--run-dir", required=True)
    run.add_argument("--source-cutoff", type=float, help="Frozen Apple-epoch Messages cutoff.")
    run.add_argument("--source-cutoff-unix", type=float, help="Frozen Unix-epoch Codex cutoff.")
    status = subparsers.add_parser("status")
    status.add_argument("--run-dir", required=True)
    args = parser.parse_args(argv)
    if not args.selftest and args.command is None: parser.error("choose --selftest, run, or status")
    if args.selftest and args.command is not None: parser.error("--selftest cannot be combined with a command")
    if args.command == "run":
        if bool(args.chat_db) != (args.source_cutoff is not None): parser.error("--chat-db requires only --source-cutoff")
        if bool(args.codex_root) != (args.source_cutoff_unix is not None): parser.error("--codex-root requires only --source-cutoff-unix")
    return args
def main(argv=None):
    os.umask(0o077)
    args = parse_args(argv)
    if args.selftest: selftest(); return 0
    try:
        if args.command == "run":
            if args.chat_db:
                cutoff = apple_seconds(args.source_cutoff)
                loader = lambda: load_messages(args.chat_db, cutoff)
            elif args.codex_root:
                loader = lambda: load_codex(args.codex_root, args.source_cutoff_unix)
            else:
                loader = load_legacy
            code, payload = execute_run(args.run_dir, loader)
        else:
            payload = read_status(args.run_dir)
            code = 0
    except SafeFailure as failure:
        payload = public_failure(failure.reason)
        code = 2
    except Exception:
        payload = public_failure("unexpected_failure")
        code = 2
    print(canonical_json(payload))
    return code
if __name__ == "__main__":
    raise SystemExit(main())
