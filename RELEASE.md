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

After the workflow finishes, the DMG will be available at:

https://github.com/skndmx/TripleS/releases

## Notes

- The app requires **macOS 26+**.
- Builds are **unsigned by default**. Downloaders may need to right-click the app and choose **Open** the first time. For wider distribution, sign and notarize before tagging.
- `build/` and `dist/` are gitignored and are not committed.
