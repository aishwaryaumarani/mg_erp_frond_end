#!/usr/bin/env bash
#
# Build the Flutter web app and publish it to the GCE VM that serves
# app.mgchemicalsandfertilizers.in.
#
# The VM has no Flutter SDK, so nothing is built there: this compiles on
# your Mac and ships the static output into nginx's document root.
# Pushing to GitHub does NOT update the site -- only this does.
#
#   ./deploy_web.sh              # build + deploy
#   ./deploy_web.sh --local      # build against a local backend, no deploy
#
set -euo pipefail

INSTANCE="instance-20260904-061100"
ZONE="asia-south1-c"
PROJECT="project-02a9ff9b-4bf2-49f1-b90"
WEB_ROOT="/var/www/erp"
SITE="https://app.mgchemicalsandfertilizers.in"
API_URL="https://api.mgchemicalsandfertilizers.in"
KEEP_BACKUPS=3   # how many /var/www/erp.bak-* to retain on the VM

cd "$(dirname "$0")"

# --- build -----------------------------------------------------------------
# The API URL is injected here rather than read from api_config.dart's
# default, so a stale local-testing default can never reach production.
if [[ "${1:-}" == "--local" ]]; then
  echo "==> Building for LOCAL backend (no deploy)"
  flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
  echo "Built build/web against 127.0.0.1:8000 -- not deployed."
  exit 0
fi

echo "==> Building against ${API_URL}"
flutter build web --release --dart-define=API_BASE_URL="${API_URL}"

# Refuse to ship a bundle pointing at localhost: served from the VM it
# would resolve to each *visitor's* machine and every API call would fail.
if grep -q '127\.0\.0\.1:8000' build/web/main.dart.js; then
  echo "ABORT: build/web/main.dart.js still references 127.0.0.1:8000" >&2
  exit 1
fi
if ! grep -q "${API_URL#https://}" build/web/main.dart.js; then
  echo "ABORT: build/web/main.dart.js does not reference ${API_URL}" >&2
  exit 1
fi
echo "    bundle points at ${API_URL}"

# --- package ---------------------------------------------------------------
# COPYFILE_DISABLE stops macOS tar embedding xattrs, which GNU tar on the
# VM would otherwise unpack as a pile of ._* files in the web root.
TARBALL="$(mktemp -t erp-web).tar.gz"
trap 'rm -f "$TARBALL"' EXIT
COPYFILE_DISABLE=1 tar czf "$TARBALL" -C build/web .
echo "==> Packaged $(du -h "$TARBALL" | cut -f1) ($(tar tzf "$TARBALL" | grep -c .) files)"

# --- upload ----------------------------------------------------------------
echo "==> Uploading to ${INSTANCE}"
gcloud compute scp "$TARBALL" "${INSTANCE}:/tmp/erp-web.tar.gz" \
  --zone="$ZONE" --project="$PROJECT" --quiet

# --- swap ------------------------------------------------------------------
STAMP="$(date +%F-%H%M)"
echo "==> Deploying to ${WEB_ROOT} (backup: ${WEB_ROOT}.bak-${STAMP})"
gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" --quiet \
  --command="set -e
sudo cp -a ${WEB_ROOT} ${WEB_ROOT}.bak-${STAMP}
sudo find ${WEB_ROOT} -mindepth 1 -delete
sudo tar xzf /tmp/erp-web.tar.gz -C ${WEB_ROOT} 2>/dev/null
sudo chown -R www-data:www-data ${WEB_ROOT}
rm -f /tmp/erp-web.tar.gz
# Keep only the most recent few rollback copies.
ls -1d ${WEB_ROOT}.bak-* 2>/dev/null | sort -r | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r sudo rm -rf
echo \"    live files: \$(ls -1 ${WEB_ROOT} | wc -l)\""

# --- verify ----------------------------------------------------------------
echo "==> Verifying ${SITE}"
CODE="$(curl -s -o /dev/null -w '%{http_code}' "${SITE}/")"
[[ "$CODE" == "200" ]] || { echo "ABORT: site returned HTTP ${CODE}" >&2; exit 1; }

# Fetch to a file rather than piping into grep: under `set -o pipefail`,
# `grep -q` exits on the first match, curl dies of SIGPIPE, and a
# *successful* check would report failure.
SERVED="$(mktemp -t erp-served)"
trap 'rm -f "$TARBALL" "$SERVED"' EXIT
curl -s "${SITE}/main.dart.js" -o "$SERVED"
grep -q "${API_URL#https://}" "$SERVED" \
  || { echo "ABORT: served bundle is not the one just built" >&2; exit 1; }
if grep -q '127\.0\.0\.1:8000' "$SERVED"; then
  echo "ABORT: served bundle references localhost" >&2
  exit 1
fi

echo
echo "Deployed. ${SITE} is serving the new build."
echo "Hard-refresh (Cmd+Shift+R) -- the service worker caches the old app."
echo "Roll back with: sudo rm -rf ${WEB_ROOT} && sudo mv ${WEB_ROOT}.bak-${STAMP} ${WEB_ROOT}"
