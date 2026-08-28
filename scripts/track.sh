#!/usr/bin/env bash
# Regenerates images.json from the tags actually published in this
# repository's GHCR namespace, and commits it when it changed.
#
# The commits keep the repository active, which prevents GitHub from
# disabling the scheduled workflow on quiet repositories.
#
# Standalone usage (scans without committing):
#   GITHUB_REPOSITORY=owner/repo bash scripts/track.sh
#
# Optional environment:
#   GITHUB_TOKEN  token used to list private packages too
#   TOOLS_FILE    alternative tools list (defaults to scripts/tools.txt)
#   GITHUB_ACTIONS  set by GitHub Actions; the commit only happens in CI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_FILE="${TOOLS_FILE:-${SCRIPT_DIR}/tools.txt}"

GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Versions recorded for a tool in the current images.json, if any. Used as a
# safety net so a transient GHCR failure never wipes the inventory.
previous_versions() {
  [[ -f images.json ]] &&
    jq -r --arg name "$1" '.[$name].versions // [] | .[]' images.json 2>/dev/null |
    sort -rVu || true
}

# Exchange the GitHub token for a GHCR pull token (the same flow
# `docker login` uses), so private packages are listed too.
ghcr_token() {
  local url="https://ghcr.io/token?service=ghcr.io&scope=repository:${1}:pull"
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    curl -fsSL -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" "${url}" 2>/dev/null | jq -r '.token'
  else
    curl -fsSL "${url}" 2>/dev/null | jq -r '.token'
  fi
}

inventory="$(mktemp)"
tags_body="$(mktemp)"
trap 'rm -f "${inventory}" "${tags_body}"' EXIT

while IFS='|' read -r name _repo _build_arg; do
  [[ -z "${name}" || "${name}" == \#* ]] && continue

  path="${GITHUB_REPOSITORY,,}/${name}"
  versions=""

  if token="$(ghcr_token "${path}")" && [[ -n "${token}" ]]; then
    http="$(curl -sS -o "${tags_body}" -w '%{http_code}' \
      -H "Authorization: Bearer ${token}" \
      "https://ghcr.io/v2/${path}/tags/list" 2>/dev/null || true)"
    case "${http}" in
      200)
        # Keep the multi-arch version tags only; the per-arch suffixed tags
        # are an implementation detail of the manifest assembly.
        versions="$(jq -r '.tags // [] | .[]' "${tags_body}" |
          grep -E '^[0-9]' | grep -vE -- '-(amd64|arm64)$' | sort -rVu || true)"
        ;;
      404)
        # The package has not been published yet: nothing to record.
        ;;
      *)
        echo "::warning::${name}: GHCR tags/list returned HTTP ${http}, keeping the last known versions."
        versions="$(previous_versions "${name}")"
        ;;
    esac
  else
    echo "::warning::${name}: could not get a GHCR pull token, keeping the last known versions."
    versions="$(previous_versions "${name}")"
  fi

  printf '%s\t%s\n' "${name}" "$(printf '%s\n' "${versions}" | paste -sd, -)" >>"${inventory}"
  printf ' - %s: %s published versions\n' \
    "${name}" "$(printf '%s\n' "${versions}" | grep -c . || true)"
done < "${TOOLS_FILE}"

jq -SRn --arg prefix "ghcr.io/${GITHUB_REPOSITORY,,}" '
  [ inputs
    | select(index("\t"))
    | split("\t")
    | { key: .[0]
      , value: { image: ($prefix + "/" + .[0])
               , versions: (.[1] | if length == 0 then [] else split(",") end) } }
    ]
  | from_entries
' < "${inventory}" > images.json

echo "images.json updated:"
cat images.json

# Commit the inventory when running inside GitHub Actions.
if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  echo "Not running in CI, skipping the commit."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add images.json
if git diff --cached --quiet; then
  echo "images.json is already up to date."
  exit 0
fi
git commit -m "chore(images): update published versions"
git pull --rebase origin "${GITHUB_REF_NAME}"
git push origin HEAD:"${GITHUB_REF_NAME}"
