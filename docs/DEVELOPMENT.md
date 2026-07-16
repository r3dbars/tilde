# Development And Release

SteadyType is a Swift 6.2 package for macOS 26. The real runtime requires Apple
Silicon and the local MLX dependencies resolved by SwiftPM.

## Build And Test

Run the same fast gate used for pull requests:

```bash
./script/proof.sh fast
```

Locally, this includes the core Swift tests. The GitHub Ubuntu job skips Swift,
so a green CI job is not proof that Swift tests ran.

Useful focused commands:

```bash
swift test --jobs 1 --filter AutocompleteLabCoreTests
swift test --jobs 1 --filter AutocompleteLabAppTests
swift test --jobs 1
./script/build_and_run.sh --bundle-only
```

`--bundle-only` builds without launching. `./script/build_and_run.sh --verify`
does launch the built app and watches it for process stability. The broad,
manual-proof-aware private-beta gate is separate:

```bash
./script/beta_readiness.sh
```

Pending manual proof remains pending even when deterministic checks pass.

## Private-Beta Release

The release path produces `dist/SteadyType.dmg` as the primary artifact and
`dist/SteadyType.zip` as a secondary operator archive.

```bash
./script/package_release.sh --check --require-developer-id --require-notary-profile
./script/package_release.sh archive
./script/package_release.sh --notarize
./script/beta_readiness.sh --check-only
```

Packaging, notarization, stapling, Gatekeeper assessment, fresh-install proof,
privacy export, and uninstall proof are distinct gates. Do not describe an
artifact as released until the exact artifact has all required proof. Record its
version, build, commit, checksum, notarization result, and date in
[`RELEASE-NOTES.md`](../RELEASE-NOTES.md).

## Current Release Hold

The app runtime policy and the release gate currently disagree about the
preferred model asset. Until they use the same pinned, installable asset and the
full private-beta gate passes, documentation must not name a release-ready
default model or imply that a public release exists.

The executable scripts are the operational source of truth:

- `script/proof.sh` for the pull-request gate
- `script/build_and_run.sh` for app bundles
- `script/package_release.sh` for signed artifacts and notarization
- `script/beta_readiness.sh` for the broad private-beta hold
