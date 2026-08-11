# Releasing Soundrift

## Git workflow

This repo uses **`main` only**. As a solo developer there is no need for a separate `develop` branch — commit directly to `main`, then tag releases from there.

## Build a DMG locally

```bash
./scripts/create-dmg.sh
```

Output:

```text
dist/Soundrift-<version>.<build>.dmg
```

Example: `dist/Soundrift-1.3.11.dmg`

The script always performs a **clean build** and verifies the app version inside the DMG matches Xcode before finishing.

To code sign (optional):

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name" ./scripts/create-dmg.sh
```

## Publish to GitHub (Option A — tag push)

Push a version tag to trigger the [Release workflow](.github/workflows/release.yml). GitHub Actions builds the app, creates the DMG, and attaches it to a new release.

```bash
git add .
git commit -m "Your release message"
git push origin main

git tag v1.3.11
git push origin v1.3.11
```

Replace `v1.3.11` with the version you are shipping. The tag should match the app version in Xcode (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`).

If a release is missing the DMG, move the tag to the latest `main` and push again:

```bash
git tag -d v1.3.11
git push origin :refs/tags/v1.3.11
git tag v1.3.11
git push origin v1.3.11
```

After the workflow finishes, the DMG will be available at:

https://github.com/skndmx/TripleS/releases

GitHub also attaches source code archives (`.zip` / `.tar.gz`) to every release automatically. The installable app is the **`Soundrift-x.y.z.dmg`** asset uploaded by the workflow.

If a release only shows source archives and no DMG, the workflow failed (often due to an older macOS/Xcode runner). Check the **Actions** tab, fix any errors, delete the broken release/tag if needed, and push the tag again.

## Notes

- The app requires **macOS 26+**.
- Builds are **ad-hoc signed by default** (proper deep sign, not `CODE_SIGNING_ALLOWED=NO`). Downloaders may still need to right-click the app and choose **Open** the first time because the release is not notarized. If macOS says the app is **damaged**, remove the download quarantine with `xattr -cr /path/to/Soundrift.app` and try again.
- For wider distribution without Gatekeeper warnings, sign with a **Developer ID** and notarize before tagging:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name" ./scripts/create-dmg.sh
```
- `build/` and `dist/` are gitignored and are not committed.
