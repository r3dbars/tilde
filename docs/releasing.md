# Releasing Tilde

One notarized build per release, published on the GitHub Releases page, tagged
`vMAJOR.MINOR.PATCH` (add `-beta.N` while the README says beta).

1. Update `CHANGELOG.md`: move "Unreleased" under the new version with the date.
2. Run the single release driver with human-reviewed pins (see
   `script/package_app.sh --help`); it builds, signs, runs the release proof
   with both pinned models, notarizes, and writes `dist/Tilde.dmg`,
   `dist/Tilde.zip`, and the checksum file:

   ```bash
   ./script/package_app.sh --llama-server <static helper> --llama-sha256 <pin> \
     --proof-gemma-model <gemma.gguf> --proof-qwen-model <qwen.gguf> \
     --build-number <git rev-list --count HEAD> --version 0.1.0 \
     --notary-profile <notarytool profile> --sign-identity <Developer ID SHA-1>
   ```

3. Tag the packaged commit and publish:

   ```bash
   git tag -a v0.1.0-beta.1 -m "Tilde 0.1.0 beta 1"
   git push origin v0.1.0-beta.1
   gh release create v0.1.0-beta.1 dist/Tilde.dmg dist/Tilde.zip dist/*.sha256 \
     --title "Tilde 0.1.0 beta 1" --notes-file <(sed -n '/^## 0.1.0/,/^## /p' CHANGELOG.md)
   ```

4. Record the helper and model pins from the proof directory in the release
   notes. The DMG never contains a model; first run downloads the pinned asset.

The models themselves are not release artifacts and are never attached.
