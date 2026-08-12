#!/usr/bin/env python3
"""Aggregate-only historical discovery for Tilde Personal Brain recipes."""

import argparse
import csv
import io
import json
import math
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unicodedata

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
    __slots__ = ("timestamp", "chat", "text", "tokens")
    def __init__(self, timestamp, chat, text):
        self.timestamp = timestamp
        self.chat = chat
        self.text = text
        self.tokens = letter_tokens(text)
class Session:
    __slots__ = ("chat", "first", "last", "messages")
    def __init__(self, message):
        self.chat = message.chat
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
    return tuple(tokens)
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
        "selected_clean_rows": summary["selected_clean_rows"],
        "selection_digest": summary["selection_digest"],
        "text_rows": summary["text_rows"],
        "attributed_body_candidates": summary["attributed_body_candidates"],
        "attributed_body_rows": summary["attributed_body_rows"],
        "attributed_body_decode_failures": summary["attributed_body_decode_failures"],
        "invalid_date_messages": invalid_dates,
    }
def sessions_for(messages):
    active = {}
    sessions = []
    for message in messages:
        session = active.get(message.chat)
        if session is None or message.timestamp - session.last > SESSION_GAP_SECONDS:
            session = Session(message)
            active[message.chat] = session
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
            "token_metrics_are_not_ui_offers": True,
            "database_read_only": True,
            "run_dir_owner_only": True,
            "atomic_writes": True,
        },
        "source_counts": source,
        "split": split_counts,
        "recipes": {"count": RECIPE_COUNT, "opportunities_per_recipe": split_counts["screen_opportunities"]},
        "representatives": None,
    }
def empty_results(opportunities=0):
    histograms = {
        (horizon, maximum, scope): {}
        for horizon, _days in HORIZONS
        for maximum in CONTEXT_LIMITS
        for scope in SCOPES
    }
    return recipe_results(histograms, opportunities)
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
        results = empty_results()
        return status, results_tsv(results), None

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
        results = empty_results()
        return status, results_tsv(results), None

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
def execute_run(database, run_dir, cutoff):
    directory = validate_run_dir(run_dir, create=True)
    try:
        cutoff = apple_seconds(cutoff)
        messages, source_counts = load_messages(database, cutoff)
        source_counts["source_cutoff_apple_seconds"] = cutoff
        status, tsv, _histograms = discover(messages, source_counts)
        if status["state"] == "complete":
            atomic_write(directory, RESULTS_FILE, tsv)
        else:
            remove_results(directory)
        atomic_write(directory, STATUS_FILE, canonical_json(status) + "\n")
        return (0 if status["state"] == "complete" else 1), status
    except SafeFailure as failure:
        remove_results(directory)
        status = base_status("invalid", failure.reason)
        atomic_write(directory, STATUS_FILE, canonical_json(status) + "\n")
        return 2, status

def remove_results(directory):
    try:
        (directory / RESULTS_FILE).unlink(missing_ok=True)
    except OSError as exc:
        raise SafeFailure("artifact_write_failed") from exc

def valid_status(payload):
    return (
        isinstance(payload, dict) and set(payload) == STATUS_KEYS
        and payload.get("schema") == SCHEMA and payload.get("label") == LABEL
        and payload.get("state") in {"complete", "incomplete", "invalid"}
        and payload.get("reason") in REASONS
        and isinstance(payload.get("source_counts"), dict)
        and isinstance(payload.get("split"), dict)
        and payload.get("recipes", {}).get("count") == RECIPE_COUNT
        and (payload.get("representatives") is None) == (payload.get("state") != "complete")
    )

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
    return payload

def selftest():
    hour = 60 * 60
    messages = [
        Message(1, "a", "RAW_SENTINEL alpha beta gamma delta epsilon zeta eta theta iota kappa lambda"),
        Message(hour, "b", "cross duplicate"),
        Message(2 * hour, "c", "cross, duplicate"),
        Message(2 * hour + 10 * 60, "c", "novel tail"),
        Message(3 * hour, "d", "sealed validation"),
        Message(4 * hour, "e", "sealed vault"),
    ]
    receipt = {"source_cutoff_apple_seconds": 123.0, "selection_digest": "0" * 64}
    status_one, tsv_one, _histograms = discover(messages, receipt)
    status_two, tsv_two, _histograms = discover(messages, receipt)
    assert canonical_json(status_one) == canonical_json(status_two) and tsv_one == tsv_two
    assert status_one["split"]["sessions"] == 5
    assert status_one["split"]["train_sessions"] == 2
    assert status_one["split"]["screen_sessions"] == 1
    assert status_one["split"]["historical_validation_sessions"] == 1
    assert status_one["split"]["historical_vault_sessions"] == 1
    assert status_one["source_counts"]["duplicate_screen_messages_excluded"] == 1
    assert status_one["source_counts"]["source_cutoff_apple_seconds"] == 123.0
    assert status_one["source_counts"]["selection_digest"] == "0" * 64
    assert status_one["recipes"]["count"] == 2048 and len(tsv_one.splitlines()) == 2049
    assert status_one["recipes"]["opportunities_per_recipe"] == 1
    assert set(status_one["representatives"]) == {
        "exploratory_max_hits", "predeclared_quiet", "predeclared_balanced",
    }
    assert "sealed" not in tsv_one
    serialized = (canonical_json(status_one) + tsv_one).lower()
    assert "raw_sentinel" not in serialized and "/users/secret/chat.db" not in serialized
    decoder = subprocess.run(
        ["xcrun", "swift", str(Path(__file__).with_name("personal_brain_messages.swift")), "--selftest"],
        capture_output=True, text=True, check=True,
    )
    decoder_status = json.loads(decoder.stdout)
    assert decoder_status["decoded_attributed_bodies"] == 2
    assert decoder_status["attributed_body_candidates"] == 3
    assert decoder_status["decoded_attributed_bodies"] + decoder_status["decode_failures"] == 3
    assert decoder_status["selection_digest_selftest"] is True
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
        code, invalid = execute_run(malformed, run_dir, 1)
        assert code == 2 and invalid["state"] == "invalid"
        assert not (run_dir / RESULTS_FILE).exists()
        persisted = (run_dir / STATUS_FILE).read_text(encoding="utf-8").lower()
        assert "raw_sentinel" not in persisted and str(root).lower() not in persisted
        broad = root / "broad"
        broad.mkdir(mode=0o755)
        broad.chmod(0o755)
        try:
            validate_run_dir(broad, create=False)
        except SafeFailure as failure:
            assert failure.reason == "invalid_run_directory"
        else:
            raise AssertionError("broad run directory did not fail closed")
    print("selftest OK: 2048 aggregate recipes, prequential holdout, and privacy boundary")

def public_failure(reason):
    return base_status("invalid", reason if reason in REASONS else "unexpected_failure")

def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Run aggregate-only Personal Brain historical discovery.")
    parser.add_argument("--selftest", action="store_true")
    subparsers = parser.add_subparsers(dest="command")
    run = subparsers.add_parser("run")
    run.add_argument("--chat-db", required=True)
    run.add_argument("--run-dir", required=True)
    run.add_argument("--source-cutoff", required=True, type=float, help="Frozen Apple-epoch source cutoff.")
    status = subparsers.add_parser("status")
    status.add_argument("--run-dir", required=True)
    args = parser.parse_args(argv)
    if not args.selftest and args.command is None:
        parser.error("choose --selftest, run, or status")
    if args.selftest and args.command is not None:
        parser.error("--selftest cannot be combined with a command")
    return args

def main(argv=None):
    os.umask(0o077)
    args = parse_args(argv)
    if args.selftest:
        selftest()
        return 0
    try:
        if args.command == "run":
            code, payload = execute_run(args.chat_db, args.run_dir, args.source_cutoff)
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
