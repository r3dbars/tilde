#!/usr/bin/env bash
# Make the Tilde identity live on this Mac — run AT the Mac, then type-test.
#
# What this deploys (committed 2026-07-29, "Tilde everywhere you can see"):
#   - keyboard's picker/input-menu name: "Tilde" (was "Inline Ghost (SteadyType Spike)")
#   - app display name "Tilde" + Tilde-branded permission dialogs
#   - onboarding alert speaks Tilde
#   - quiet-on-brain-down (1721beeb) rides along — first deploy since
#
# What this deliberately does NOT change (plumbing identity, invisible):
#   - bundle ids (bar.r3d.steadytype / bar.r3d.inputmethod.InlineGhost)
#   - Application Support/SteadyType + SteadyType-usage folders
#   - process/binary names, LaunchAgent labels, socket path
#   Changing those resets TCC grants, saved defaults (RuntimeSetting!), the
#   input-source registration, and the capture ferry offsets. They are how
#   macOS *knows* this app. Rename them only with a dedicated migration and
#   a full re-onboard budget — or never (Apple's own internals still say
#   "Macintosh"). Nothing user-visible says SteadyType after this deploy.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> keyboard (sign + notarize + install — picker name becomes Tilde)"
./script/build_ime.sh

echo "==> app"
./script/build_and_run.sh --verify

echo "==> blessed restart"
./script/restart_app.sh

echo "==> smoke"
./script/real_app_smoke.sh || echo "SMOKE FAILED — investigate before typing on"

echo
echo "Done. Check: input menu says Tilde; menu bar icon tooltip says Tilde;"
echo "then type a sentence anywhere and confirm ghosts still feel right."
