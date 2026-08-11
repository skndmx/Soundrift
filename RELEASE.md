# Releasing Soundrift

Maintainer notes for cutting a release. End users can ignore this file — install from [GitHub Releases](https://github.com/skndmx/Soundrift/releases).

## Workflow

This repo uses **`main` only**. Ship by committing to `main`, then pushing a version tag.

## Build a DMG locally

```bash
./scripts/create-dmg.sh
```

Output:

```text
dist/Soundrift-<version>.<build>.dmg
```

The script performs a clean Release build, ad-hoc deep-signs the app, and verifies the version inside the DMG.

Optional Developer ID signing:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name" ./scripts/create-dmg.sh
```

## Publish (tag push)

Pushing a `v*` tag runs [.github/workflows/release.yml](.github/workflows/release.yml), which builds the DMG and attaches it to a GitHub Release.

```bash
git push origin main

git tag v1.3.14
git push origin v1.3.14
```

The tag should match the app version in Xcode (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`, e.g. `1.3` + `14` → present as **1.3.14**).

### Fix a bad / incomplete release

```bash
git tag -d v1.3.14
git push origin :refs/tags/v1.3.14
git tag v1.3.14
git push origin v1.3.14
```

Releases: https://github.com/skndmx/Soundrift/releases  

The installable artifact is the **`Soundrift-*.dmg`** asset. Source zip/tarball attachments are automatic and not the app.

If a release has no DMG, check the **Actions** tab — the workflow may have failed (wrong runner / Xcode).

## Notes

- Requires **macOS 26+** to build and run.
- Default CI/local builds are **ad-hoc signed**, not notarized. Downloaders may need `xattr -cr` + right-click **Open**.
- For Gatekeeper-clean distribution, use a Developer ID certificate and notarize before publishing.
- `build/`, `dist/`, and `archives/` are gitignored.
