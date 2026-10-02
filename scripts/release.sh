#!/usr/bin/env bash
# One command to release Kuzu Help: the next build number, then the app built
# and uploaded to Google Play and App Store Connect (README, 'One-command release').
#
#   scripts/release.sh               both stores
#   scripts/release.sh android       Google Play only
#   scripts/release.sh ios           App Store Connect only
#
# Options:
#   --rollout      Google Play: send it for review and roll it out once approved.
#                  Without it, it waits as a draft for you to roll out in Play Console.
#   --track NAME   Google Play track: production (default), beta, alpha or internal.
#   --no-bump      Keep the build number: to retry a store whose upload failed.
#   --dry-run      Check everything and show what would happen; change nothing.
set -euo pipefail

cd "$(dirname "$0")/.."

PACKAGE=bt.kuzuhelp.app
DEFINES=config/dev.json
AAB=build/app/outputs/bundle/release/app-release.aab
PLAY_KEY="${PLAY_SERVICE_ACCOUNT:-$HOME/.kuzu-help/play-service-account.json}"

platforms=()
track=production
status=draft
bump=true
dry=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    android | ios) platforms+=("$1") ;;
    all) platforms=(android ios) ;;
    --rollout) status=completed ;;
    --track) track="${2:?--track needs a name, e.g. internal}"; shift ;;
    --no-bump) bump=false ;;
    --dry-run) dry=true ;;
    -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1 (see scripts/release.sh --help)" >&2; exit 2 ;;
  esac
  shift
done
[[ ${#platforms[@]} -gt 0 ]] || platforms=(android ios)

wants() { [[ " ${platforms[*]} " == *" $1 "* ]]; }
step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
# Runs a command; with --dry-run, only says what it would run.
run() { if $dry; then printf '  would run: %s\n' "$*"; else "$@"; fi; }

# --- Everything needed is there, before anything changes -------------------
problems=()
[[ -f $DEFINES ]] || problems+=("$DEFINES is missing (README, First-time setup, step 5).")
command -v flutter >/dev/null || problems+=("flutter isn't on the PATH.")
if wants android; then
  [[ -f android/key.properties ]] ||
    problems+=("android/key.properties is missing: Google Play only takes builds signed with the upload key.")
  [[ -f $PLAY_KEY ]] ||
    problems+=("No Google Play service account key at $PLAY_KEY (README, One-command release; or set PLAY_SERVICE_ACCOUNT).")
  if ! command -v node >/dev/null || ! node -e 'process.exit(+process.versions.node.split(".")[0] >= 18 ? 0 : 1)'; then
    problems+=("Node.js 18 or newer is needed to upload to Google Play (https://nodejs.org).")
  fi
fi
if wants ios; then
  command -v xcodebuild >/dev/null || problems+=("Xcode is needed for the iPhone app, on a Mac.")
  [[ -f ios/UploadOptions.plist ]] || problems+=("ios/UploadOptions.plist is missing.")
fi
if [[ ${#problems[@]} -gt 0 ]]; then
  printf '✗ %s\n' "${problems[@]}" >&2
  exit 1
fi

# --- The next build number (pubspec.yaml: version: 1.0.0+6 -> 1.0.0+7) -------
# Both stores refuse a build number they've had before.
current=$(sed -n 's/^version: *//p' pubspec.yaml)
if [[ ! $current =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  echo "✗ pubspec.yaml's version should look like 1.0.0+6, not '$current'." >&2
  exit 1
fi
name=${BASH_REMATCH[1]}
build=${BASH_REMATCH[2]}
if $bump; then
  build=$((build + 1))
  if ! $dry; then perl -pi -e "s/^version: .*/version: $name+$build/" pubspec.yaml; fi
fi
step "Kuzu Help $name ($build) for ${platforms[*]}"
$bump && echo "  pubspec.yaml: version $current -> $name+$build"
wants android && echo "  Google Play: $track track, $([[ $status == completed ]] && echo 'sent for review, then rolled out' || echo 'as a draft')"

step "Cleaning the last build"
run flutter clean
run flutter pub get

release_android() {
  step "Android: building the app bundle"
  run flutter build appbundle --release --dart-define-from-file="$DEFINES" || return 1
  step "Android: uploading to Google Play"
  run node scripts/play_upload.mjs --aab "$AAB" --package "$PACKAGE" --key "$PLAY_KEY" \
    --track "$track" --status "$status" || return 1
}

release_ios() {
  step "iOS: building the archive"
  run flutter build ipa --release --dart-define-from-file="$DEFINES" || return 1
  step "iOS: uploading to App Store Connect"
  run xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
    -exportOptionsPlist ios/UploadOptions.plist -exportPath build/ios/upload -allowProvisioningUpdates || return 1
}

# One store failing doesn't stop the other.
done_ok=()
failed=()
for platform in "${platforms[@]}"; do
  if "release_$platform"; then done_ok+=("$platform"); else failed+=("$platform"); fi
done

step "Summary: $name ($build)"
$dry && echo "  Dry run: nothing was built, uploaded or changed."
for platform in "${done_ok[@]+"${done_ok[@]}"}"; do
  case $platform in
    android)
      if [[ $status == completed ]]; then
        echo "✓ Google Play: sent for review on the $track track; it rolls out once approved."
      else
        echo "✓ Google Play: a draft on the $track track. In Play Console, open Kuzu Help's $track"
        echo "  release (Test and release), then Edit release -> Start rollout."
      fi
      ;;
    ios)
      echo "✓ App Store Connect: uploaded. Once processed (up to about 30 minutes) it's in TestFlight;"
      echo "  to publish: App Store Connect -> the version -> pick this build -> Add for Review -> Submit."
      ;;
  esac
done
for platform in "${failed[@]+"${failed[@]}"}"; do
  echo "✗ $platform failed (see above). Fix it, then: scripts/release.sh $platform --no-bump"
done
if ! $dry && $bump && [[ ${#done_ok[@]} -gt 0 ]]; then
  echo "  Commit pubspec.yaml (version $name+$build) so the next release counts on from it."
fi
[[ ${#failed[@]} -eq 0 ]]
