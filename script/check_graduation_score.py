#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT_DIR / "docs/product/proof-manifest.json"


@dataclass(frozen=True)
class ExpectedSurface:
    surface: str
    decision: str
    proof_state: str
    smoke_command: str | None
    profile_bundles: tuple[str, ...]
    required_proof: tuple[str, ...]


EXPECTED_SURFACES: tuple[ExpectedSurface, ...] = (
    ExpectedSurface(
        surface="Google Docs in Chrome",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture google-docs",
        profile_bundles=("com.google.Chrome",),
        required_proof=(
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Notion browser or desktop",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture notion",
        profile_bundles=("com.google.Chrome", "notion.id"),
        required_proof=(
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Slack browser or desktop",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture browser-slack",
        profile_bundles=("com.google.Chrome", "com.tinyspeck.slackmacgap"),
        required_proof=(
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Discord browser or desktop",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture browser-discord",
        profile_bundles=(
            "com.google.Chrome",
            "com.hnc.Discord",
            "com.hnc.DiscordPTB",
            "com.hnc.DiscordCanary",
        ),
        required_proof=(
            "correct placement",
            "safe Tab",
            "no submit/send",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Mail compose",
        decision="diagnostics-only",
        proof_state="blocked",
        smoke_command=None,
        profile_bundles=("com.apple.mail",),
        required_proof=(
            "compose-body-only placement",
            "safe Tab",
            "no recipient/search/account-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Browser webmail",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture browser-webmail",
        profile_bundles=(
            "com.google.Chrome",
            "com.apple.Safari",
            "com.brave.Browser",
            "org.mozilla.firefox",
        ),
        required_proof=(
            "compose-body-only placement",
            "safe one-word Tab",
            "no send",
            "no recipient/subject/search/account-field leak",
            "verified insertion",
            "undo/recovery",
            "latency proof",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Browser ChatGPT",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture browser-chatgpt",
        profile_bundles=(
            "com.google.Chrome",
            "com.openai.chat",
            "com.openai.ChatGPT",
            "com.openai.atlas",
        ),
        required_proof=(
            "correct placement",
            "safe one-word Tab",
            "no submit/send",
            "no tool/context side effect",
            "no sensitive-field leak",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Chrome production text fields",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture production-text-fields",
        profile_bundles=("com.google.Chrome",),
        required_proof=(
            "local fixture proof is not enough",
            "disposable production-page proof",
            "correct placement",
            "safe Tab",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Claude desktop layouts",
        decision="proof-only",
        proof_state="partial",
        smoke_command="script/real_app_smoke.sh claude-empty --manual-gate",
        profile_bundles=("com.anthropic.claudefordesktop",),
        required_proof=(
            "empty prompt layout",
            "long prompt layout",
            "wrapped prompt layout",
            "narrow window layout",
            "context layout",
            "light appearance",
            "dark appearance",
        ),
    ),
    ExpectedSurface(
        surface="Codex layouts",
        decision="proof-only",
        proof_state="partial",
        smoke_command="script/real_app_smoke.sh codex --manual-gate",
        profile_bundles=("com.openai.codex",),
        required_proof=(
            "more prompt layouts before raising beyond the default Codex composer",
        ),
    ),
    ExpectedSurface(
        surface="Obsidian long notes",
        decision="supported",
        proof_state="complete",
        smoke_command="script/real_app_smoke.sh obsidian-long-note --manual-gate",
        profile_bundles=("md.obsidian",),
        required_proof=(
            "correct scrolled CodeMirror caret source",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
    ExpectedSurface(
        surface="Real Monaco and CodeMirror editors",
        decision="blocked",
        proof_state="blocked",
        smoke_command="script/real_app_smoke.sh chrome --fixture monaco-official",
        profile_bundles=(
            "com.google.Chrome",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",
        ),
        required_proof=(
            "official CodeMirror proof",
            "official Monaco proof",
            "default-AX Monaco proof",
            "verified insertion",
            "undo/recovery",
            "screenshot-backed current-head evidence",
        ),
    ),
)


@dataclass
class Check:
    points: int
    label: str
    passed: bool
    detail: str = ""


def load_manifest(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        print(f"Graduation score check failed: missing manifest {path}", file=sys.stderr)
        raise SystemExit(1)
    except json.JSONDecodeError as error:
        print(f"Graduation score check failed: invalid JSON in {path}: {error}", file=sys.stderr)
        raise SystemExit(1)


def text(path: str) -> str:
    return (ROOT_DIR / path).read_text(encoding="utf-8")


def rows_by_surface(manifest: dict) -> dict[str, dict]:
    rows = manifest.get("graduationDecisions")
    if not isinstance(rows, list):
        return {}
    result: dict[str, dict] = {}
    for row in rows:
        if isinstance(row, dict):
            surface = str(row.get("surface", "")).strip()
            if surface:
                result[surface] = row
    return result


def contains_all(haystack: str, needles: tuple[str, ...]) -> bool:
    return all(needle in haystack for needle in needles)


def proof_manifest_validator_passes(manifest_path: Path) -> tuple[bool, str]:
    result = subprocess.run(
        [
            sys.executable,
            str(ROOT_DIR / "script/check_proof_manifest.py"),
            "--manifest",
            str(manifest_path),
            "--skip-profile-coverage",
            "--require-current-commit",
        ],
        cwd=ROOT_DIR,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    output = result.stdout.strip()
    if result.returncode == 0:
        return True, ""
    tail = "\n".join(output.splitlines()[-8:])
    return False, tail or "proof manifest validator failed"


def manifest_checks(manifest: dict) -> list[Check]:
    expected_names = tuple(surface.surface for surface in EXPECTED_SURFACES)
    rows = rows_by_surface(manifest)
    manifest_checker = text("script/check_proof_manifest.py")
    validator_passed, validator_detail = proof_manifest_validator_passes(DEFAULT_MANIFEST)
    checks: list[Check] = []
    checks.append(
        Check(
            6,
            "Manifest has exactly the focused graduation queue",
            len(rows) == len(EXPECTED_SURFACES) and set(rows) == set(expected_names),
            f"found {len(rows)} row(s)",
        )
    )
    checks.append(
        Check(
            4,
            "Manifest keeps stable surface names",
            list(rows) == list(expected_names),
            "surface order or names drifted",
        )
    )
    checks.append(
        Check(
            5,
            "Manifest decisions match the scorecard",
            all(rows.get(expected.surface, {}).get("decision") == expected.decision for expected in EXPECTED_SURFACES),
            "one or more decisions changed",
        )
    )
    checks.append(
        Check(
            4,
            "Manifest proof states match decisions",
            all(rows.get(expected.surface, {}).get("proofState") == expected.proof_state for expected in EXPECTED_SURFACES),
            "one or more proofState values changed",
        )
    )
    checks.append(
        Check(
            4,
            "Manifest profile bundles cover each surface",
            all(
                set(expected.profile_bundles).issubset(set(rows.get(expected.surface, {}).get("profileBundles", [])))
                for expected in EXPECTED_SURFACES
            ),
            "one or more profileBundles lists are incomplete",
        )
    )
    checks.append(
        Check(
            3,
            "Manifest smoke commands are exact and safe",
            all(rows.get(expected.surface, {}).get("smokeCommand") == expected.smoke_command for expected in EXPECTED_SURFACES),
            "one or more smokeCommand values drifted",
        )
    )
    checks.append(
        Check(
            2,
            "Manifest required proof gates are explicit and current-source checked",
            all(
                set(expected.required_proof).issubset(set(rows.get(expected.surface, {}).get("requiredProof", [])))
                for expected in EXPECTED_SURFACES
            )
            and "EXPECTED_GRADUATION_DECISIONS" in manifest_checker
            and "verify_graduation_decisions" in manifest_checker,
            "one or more requiredProof lists are incomplete",
        )
    )
    checks.append(
        Check(
            2,
            "Proof manifest validator passes with current source-compatible evidence",
            validator_passed
            and contains_all(
                manifest_checker,
                (
                    "CURRENT_PROOF_SOURCE_PATHS",
                    "source_commit_is_current_compatible",
                    "proof_sensitive_worktree_changes",
                    "script/build_and_run.sh",
                    "script/real_app_smoke.sh",
                    "script/local_completion_runtime.py",
                ),
            ),
            validator_detail or "proof manifest validator or current-source path rules failed",
        )
    )
    return checks


def profile_checks() -> list[Check]:
    compatibility = text("Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift")
    app_profiles = text("Sources/AutocompleteLabCore/Compatibility/AppCompatibilityProfile.swift")
    app_delegate = text("Sources/AutocompleteLabApp/App/AppDelegate.swift")
    app_proof_mode = text("Sources/AutocompleteLabResearch/AppProofModeCoordinator.swift")
    browser_policy = text("Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift")
    proof_mode_policy = text("Sources/AutocompleteLabResearch/ProofModeScopePolicy.swift")
    compatibility_tests = text("Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift")
    app_profile_tests = text("Tests/AutocompleteLabCoreTests/AppCompatibilityProfileTests.swift")
    browser_policy_tests = text("Tests/AutocompleteLabCoreTests/BrowserHostedSurfacePolicyTests.swift")
    proof_mode_policy_tests = text("Tests/AutocompleteLabCoreTests/ProofModeScopePolicyTests.swift")
    checks = [
        Check(
            4,
            "CompatibilityProfile has a graduation decision field",
            contains_all(
                compatibility,
                (
                    "public enum CompatibilityGraduationDecision",
                    "case wordOnly = \"word-only\"",
                    "case diagnosticsOnly = \"diagnostics-only\"",
                    "public let graduationDecision",
                    "defaultGraduationDecision",
                ),
            ),
        ),
        Check(
            8,
            "Profile tests lock supported, word-only, diagnostics-only, and blocked decisions",
            contains_all(
                compatibility_tests,
                (
                    "High-value writing surfaces have explicit graduation decisions",
                    "graduationDecision == .supported",
                    "graduationDecision == .wordOnly",
                    "graduationDecision == .diagnosticsOnly",
                    "graduationDecision == .blocked",
                    "supportStatus(for: \"com.microsoft.VSCode\").supportLevel == .diagnosticsOnly",
                ),
            ),
        ),
        Check(
            4,
            "Prompt-app word-only profiles keep full accept off",
            contains_all(
                compatibility_tests,
                (
                    "\"com.openai.codex\"",
                    "\"com.anthropic.claudefordesktop\"",
                    "!profile.supportsFullAcceptance",
                    "profile.requiresNoSubmitAcceptanceProof",
                ),
            ),
        ),
        Check(
            4,
            "High-risk browser and collaboration surfaces stay blocked, redacted, and proof scoped",
            contains_all(
                app_profiles
                + app_delegate
                + app_proof_mode
                + app_profile_tests
                + browser_policy
                + browser_policy_tests
                + proof_mode_policy
                + proof_mode_policy_tests,
                (
                    "notion-blocked",
                    "slack-blocked",
                    "discord-blocked",
                    "High-value unproven collaboration apps stay blocked at the routing layer",
                    "acceptMode == .none",
                    "redactedTraceMetadata",
                    "blockedSurfaceTextRedacted",
                    "Chrome sensitive pages outrank service fingerprints",
                    "ProofModeScopePolicy",
                    "scopePolicy.allows(",
                    "suggestionBundleIdentifier: profile.bundleIdentifier",
                    "Active proof mode blocks apps outside the requested proof target",
                    "Active proof mode can allow a virtual proof profile through its suggestion bundle",
                ),
            ),
        ),
    ]
    return checks


def smoke_checks() -> list[Check]:
    smoke = text("script/real_app_smoke.sh")
    smoke_self_test = text("script/real_app_smoke_self_test.sh")
    fixtures = (
        "google-docs",
        "notion",
        "browser-webmail",
        "browser-chatgpt",
        "browser-slack",
        "browser-discord",
    )
    return [
        Check(
            4,
            "Blocked Chrome fixtures are valid fixture labels",
            contains_all(smoke, fixtures),
        ),
        Check(
            4,
            "Blocked Chrome fixtures have a dedicated classifier",
            contains_all(smoke, ("chrome_fixture_is_blocked_high_value_surface",) + fixtures),
        ),
        Check(
            5,
            "Blocked Chrome fixtures fail before live typing",
            contains_all(
                smoke,
                (
                    "Blocked Chrome fixture: $CHROME_FIXTURE",
                    "No Chrome typing was attempted.",
                    "exit 1",
                ),
            ),
        ),
        Check(
            3,
            "Dry-run plan says the live service will not be typed into",
            contains_all(
                smoke,
                (
                    "blocked preflight only",
                    "refuses to type into the live service",
                ),
            ),
        ),
        Check(
            4,
            "Smoke self-test proves the blocked fixtures fail closed",
            contains_all(
                smoke_self_test,
                fixtures
                + (
                    "expected Chrome $blocked_fixture to fail closed before typing",
                    "No Chrome typing was attempted.",
                ),
            ),
        ),
    ]


def docs_checks() -> list[Check]:
    compatibility_matrix = text("docs/product/compatibility-matrix.md")
    app_proof_matrix = text("docs/product/app-proof-matrix.md")
    scorecard_path = ROOT_DIR / "docs/product/graduation-scorecard.md"
    scorecard = scorecard_path.read_text(encoding="utf-8") if scorecard_path.exists() else ""
    names_and_decisions = tuple(
        f"| {expected.surface} | {expected.decision} |" for expected in EXPECTED_SURFACES
    )
    return [
        Check(
            6,
            "Compatibility matrix lists all focused graduation decisions",
            "## Focused Graduation Queue" in compatibility_matrix
            and contains_all(compatibility_matrix, names_and_decisions),
        ),
        Check(
            5,
            "App proof matrix lists all focused graduation decisions",
            "## Focused Graduation Decisions" in app_proof_matrix
            and contains_all(app_proof_matrix, names_and_decisions),
        ),
        Check(
            4,
            "Graduation scorecard documents the meaning of 100/100",
            contains_all(
                scorecard,
                (
                    "Score: 100/100",
                    "fail-closed graduation contract",
                    "does not mean every listed app is supported",
                ),
            ),
        ),
    ]


def status_and_test_checks() -> list[Check]:
    status = text("script/manual_smoke_status.sh")
    status_self_test = text("script/manual_smoke_self_test.sh")
    compatibility_tests = text("Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift")
    app_profile_tests = text("Tests/AutocompleteLabCoreTests/AppCompatibilityProfileTests.swift")
    status_lines = (
        "Google Docs browser: blocked",
        "Notion browser/desktop: blocked",
        "Slack browser/desktop: blocked",
        "Discord browser/desktop: blocked",
        "Mail compose: diagnostics-only",
        "Browser webmail: blocked",
        "Browser ChatGPT: blocked",
        "Chrome production text fields: blocked",
        "Claude desktop layouts: proof-only",
        "Codex layouts: proof-only",
        "Obsidian long notes: supported",
        "Real Monaco and CodeMirror editors: blocked",
    )
    return [
        Check(
            5,
            "Manual smoke status prints every focused decision",
            contains_all(status, status_lines),
        ),
        Check(
            3,
            "Manual smoke self-test locks focused decision output",
            contains_all(
                status_self_test,
                (
                    "Focused graduation decisions:",
                    "Google Docs browser: blocked",
                    "Mail compose: diagnostics-only",
                    "Browser webmail: blocked",
                    "Chrome production text fields: blocked",
                    "Claude desktop layouts: proof-only",
                    "Codex layouts: proof-only",
                ),
            ),
        ),
        Check(
            4,
            "Compatibility profile tests lock the high-value queue",
            contains_all(
                compatibility_tests,
                (
                    "High-value writing surfaces have explicit graduation decisions",
                    "com.openai.codex",
                    "com.anthropic.claudefordesktop",
                    "com.apple.mail",
                    "com.hnc.DiscordCanary",
                ),
            ),
        ),
        Check(
            3,
            "App compatibility profile tests lock blocked collaboration routing",
            contains_all(
                app_profile_tests,
                (
                    "High-value unproven collaboration apps stay blocked at the routing layer",
                    "notion.id",
                    "com.tinyspeck.slackmacgap",
                    "com.hnc.Discord",
                ),
            ),
        ),
    ]


def score(manifest_path: Path) -> tuple[int, list[Check]]:
    manifest = load_manifest(manifest_path)
    checks = (
        manifest_checks(manifest)
        + profile_checks()
        + smoke_checks()
        + docs_checks()
        + status_and_test_checks()
    )
    total = sum(check.points for check in checks if check.passed)
    return total, checks


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Score the focused high-value app graduation contract."
    )
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--json", action="store_true", help="Print machine-readable score output.")
    parser.add_argument("--min-score", type=int, default=100, help="Minimum passing score.")
    parser.add_argument(
        "--allow-partial",
        action="store_true",
        help="Print the score without failing below 100.",
    )
    args = parser.parse_args()
    if not 0 <= args.min_score <= 100:
        print("--min-score must be between 0 and 100", file=sys.stderr)
        return 2

    total, checks = score(Path(args.manifest))
    failed = [check for check in checks if not check.passed]
    payload = {
        "score": total,
        "status": "pass" if total >= args.min_score else "fail",
        "threshold": args.min_score,
        "hardGateBlockers": [check.label for check in failed],
        "nextProof": [check.detail for check in failed if check.detail],
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"Graduation score: {total}/100")
        for check in checks:
            mark = "PASS" if check.passed else "FAIL"
            print(f"[{mark}] {check.points:>2} - {check.label}")
            if not check.passed and check.detail:
                print(f"       {check.detail}")

    if total < args.min_score and not args.allow_partial:
        print(f"Graduation score check failed: expected at least {args.min_score}/100.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
