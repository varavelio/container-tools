#!/usr/bin/env bash
# Plans which tool versions need to be built and published.
#
# For every tool in tools.txt it lists the recent stable upstream releases
# (newest first), skips the ones whose multi-arch tag already exists in GHCR,
# and emits the dynamic matrices consumed by the build and merge jobs.
#
# Standalone usage (uses the GitHub API anonymously):
#   GITHUB_REPOSITORY=owner/repo bash scripts/resolve.sh
#
# Optional environment:
#   GITHUB_TOKEN  token used for the GitHub API and GHCR lookups
#   ONLY_TOOLS    comma-separated subset of tool names (empty = all)
#   FORCE         "true" to queue the latest version even if already published
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_FILE="${TOOLS_FILE:-${SCRIPT_DIR}/tools.txt}"

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
ONLY_TOOLS="${ONLY_TOOLS:-}"
FORCE="${FORCE:-}"

# How many recent upstream releases to inspect per tool, and how many missing
# versions may be queued per tool in a single run. This lets the workflow
# catch up gradually if it falls several releases behind.
HISTORY_DEPTH=10
MAX_PENDING=5

# Images always live in this repository's GHCR namespace:
#   ghcr.io/<owner>/<repo>/<tool>:<upstream-version>
IMAGE_PREFIX="ghcr.io/${GITHUB_REPOSITORY,,}"
readonly VERSION_RE='^[0-9]+(\.[0-9]+){1,3}(-[A-Za-z0-9.]+)?$'

ONLY_TOOLS="$(printf '%s' "${ONLY_TOOLS}" | tr -d ' ' | sed -e 's/^,*//' -e 's/,*$//')"

build_rows=()
merge_rows=()
summary_lines=()

while IFS='|' read -r name repo build_arg; do
  [[ -z "${name}" || "${name}" == \#* ]] && continue

  if [[ -n "${ONLY_TOOLS}" && ",${ONLY_TOOLS}," != *",${name},"* ]]; then
    echo "Skipping ${name}: not selected in ONLY_TOOLS."
    continue
  fi

  # Recent stable upstream releases, newest first, without any "v" prefix.
  gh_api_args=(-H "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    gh_api_args+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  versions="$(
    curl -fsSL "${gh_api_args[@]}" \
      "https://api.github.com/repos/${repo}/releases?per_page=100" |
      jq -r '.[] | select(.draft != true and .prerelease != true)
             | .tag_name | sub("^v"; "")' |
      sort -rVu | head -n "${HISTORY_DEPTH}"
  )"

  pending=0
  while IFS= read -r version; do
    [[ -z "${version}" ]] && continue

    if [[ ! "${version}" =~ ${VERSION_RE} ]]; then
      echo "::warning::${name}: ignoring unexpected upstream version '${version}'."
      continue
    fi

    # Idempotency: skip versions whose multi-arch tag already exists.
    if [[ "${FORCE}" != "true" ]] &&
       docker manifest inspect "${IMAGE_PREFIX}/${name}:${version}" >/dev/null 2>&1; then
      continue
    fi

    merge_rows+=("$(jq -nc --arg name "${name}" --arg version "${version}" \
      '{name: $name, version: $version}')")

    for combo in "amd64|ubuntu-24.04" "arm64|ubuntu-24.04-arm"; do
      IFS='|' read -r platform os <<<"${combo}"
      build_rows+=("$(jq -nc \
        --arg name "${name}" --arg version "${version}" \
        --arg build_arg "${build_arg}" --arg platform "${platform}" --arg os "${os}" \
        '{name: $name, version: $version, build_arg: $build_arg, platform: $platform, os: $os}')")
    done

    summary_lines+=("- \`${name}:${version}\`")
    pending=$((pending + 1))

    # Forced runs only ever rebuild the latest version.
    if [[ "${FORCE}" == "true" || "${pending}" -ge "${MAX_PENDING}" ]]; then
      break
    fi
  done <<<"${versions}"
done < "${TOOLS_FILE}"

if [[ "${#build_rows[@]}" -eq 0 ]]; then
  matrix='{"include":[]}'
  manifest_matrix='{"include":[]}'
else
  matrix="$(printf '%s\n' "${build_rows[@]}" | jq -cs '{include: .}')"
  manifest_matrix="$(printf '%s\n' "${merge_rows[@]}" | jq -cs '{include: .}')"
fi

{
  echo "matrix=${matrix}"
  echo "manifest_matrix=${manifest_matrix}"
  echo "image_prefix=${IMAGE_PREFIX}"
} >>"${GITHUB_OUTPUT:-/dev/null}"

{
  echo "### Image build plan"
  echo
  echo "Namespace: \`${IMAGE_PREFIX}/<tool>\` (pinned versions only, no \`latest\`)."
  echo
  if [[ "${#summary_lines[@]}" -eq 0 ]]; then
    echo "Nothing to do: every tracked upstream release is already published."
  else
    echo "Versions to build and publish:"
    printf '%s\n' "${summary_lines[@]}"
  fi
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
