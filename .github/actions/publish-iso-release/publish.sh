#!/usr/bin/env bash
# Publish one OneDrive-hosted Qubix installer as a GitHub Release.
#
# Release creation is required and fails the job. Cleanup is deliberately best-effort:
# transient GitHub API failures must not hide a newly published, valid installer. New
# release tags carry a sortable UTC timestamp; cleanup accepts both that family and the
# legacy variant-first tags emitted before the ordering fix.

set -euo pipefail

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

die() {
  echo "iso-release: $*" >&2
  exit 1
}

require_value() {
  local variable_name=$1
  [[ -n "${!variable_name:-}" ]] || die "${variable_name} is required"
}

warn() {
  echo "::warning::iso-release: $*"
}

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

# Delete a generated release first and its backing tag second. A missing release is fine:
# older OneDrive versions can predate this feature, and another matrix cell can win an age
# cleanup race. Cleanup failures are warnings so publication remains discoverable.
delete_release_and_tag() {
  local tag=$1
  local encoded_tag
  local lookup_status
  local release_id=""
  local release_deleted=1

  encoded_tag="$(urlencode "${tag}")"
  lookup_status="$(curl --silent --show-error \
    --header "Authorization: Bearer ${GH_TOKEN}" \
    --header 'Accept: application/vnd.github+json' \
    --output "${work_dir}/release-lookup" \
    --write-out '%{http_code}' \
    "${GITHUB_API_URL}/repos/${QUBIX_RELEASE_REPOSITORY}/releases/tags/${encoded_tag}")" || {
      warn "cannot inspect GitHub Release ${tag}"
      return 0
    }
  if [[ "${lookup_status}" == 200 ]]; then
    release_id="$(jq -er '.id' "${work_dir}/release-lookup")" || {
      warn "cannot read release ID for ${tag}"
      return 0
    }
    if ! gh api --method DELETE "/repos/${QUBIX_RELEASE_REPOSITORY}/releases/${release_id}" >/dev/null 2>&1; then
      warn "cannot purge GitHub Release ${tag}"
      release_deleted=0
    else
      echo "Purged GitHub Release ${tag}"
    fi
  elif [[ "${lookup_status}" != 404 ]]; then
    warn "cannot inspect GitHub Release ${tag} (HTTP ${lookup_status})"
    return 0
  fi

  if (( release_deleted == 1 )); then
    if ! gh api --method DELETE "/repos/${QUBIX_RELEASE_REPOSITORY}/git/refs/tags/${encoded_tag}" >/dev/null 2>&1; then
      # A missing tag is the normal case for a OneDrive version that predates releases.
      echo "GitHub tag ${tag} was already absent or could not be purged"
    fi
  fi
}

# OneDrive retention returns only a version-directory name. Legacy tags are directly
# derivable; timestamp-prefixed tags are located by their exact validated suffix so the
# matching release can be removed without touching another variant or version.
delete_release_for_version() {
  local version=$1
  local legacy_tag="iso-${QUBIX_ISO_VARIANT}-${QUBIX_RETENTION_CHANNEL}-${version}"
  local candidate_tag
  local release_tags

  delete_release_and_tag "${legacy_tag}"

  if ! release_tags="$(gh api --paginate \
    "/repos/${QUBIX_RELEASE_REPOSITORY}/releases?per_page=100" \
    --jq '.[].tag_name')"; then
    warn "cannot list GitHub Releases while purging OneDrive version ${version}"
    return 0
  fi

  while IFS= read -r candidate_tag; do
    [[ "${candidate_tag}" == iso-z-??????????????-"${QUBIX_ISO_VARIANT}"-"${QUBIX_RETENTION_CHANNEL}"-"${version}" ]] \
      || continue
    [[ "${candidate_tag:6:14}" =~ ^[0-9]{14}$ ]] || continue
    delete_release_and_tag "${candidate_tag}"
  done <<< "${release_tags}"
}

# ── Validate trusted workflow inputs before constructing API targets or Markdown ───────
for required_name in \
  GH_TOKEN QUBIX_RELEASE_REPOSITORY QUBIX_ISO_VARIANT QUBIX_RETENTION_CHANNEL \
  QUBIX_SOURCE_EVENT QUBIX_SOURCE_SHA QUBIX_IMAGE_NAME QUBIX_IMAGE_TAG \
  QUBIX_IMAGE_DIGEST QUBIX_FEDORA_VERSION QUBIX_ISO_VERSION QUBIX_ISO_NAME \
  QUBIX_ISO_URL QUBIX_CHECKSUM_NAME QUBIX_CHECKSUM_URL QUBIX_ISO_SHA256 \
  QUBIX_ISO_SIZE_BYTES QUBIX_PURGED_VERSIONS QUBIX_KEEP_VERSIONS \
  GITHUB_SERVER_URL GITHUB_API_URL GITHUB_RUN_ID GITHUB_RUN_ATTEMPT GITHUB_OUTPUT; do
  require_value "${required_name}"
done

command -v gh >/dev/null && command -v jq >/dev/null && command -v date >/dev/null \
  && command -v curl >/dev/null || die "gh, jq, date, and curl are required"

[[ "${QUBIX_RELEASE_REPOSITORY}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
  || die "invalid GitHub repository"
[[ "${QUBIX_ISO_VARIANT}" =~ ^(standard|cachyos|nvidia)$ ]] || die "invalid ISO variant"
[[ "${QUBIX_RETENTION_CHANNEL}" =~ ^(scheduled|push)$ ]] || die "invalid retention channel"
[[ "${QUBIX_SOURCE_EVENT}" =~ ^(schedule|push|workflow_dispatch)$ ]] || die "invalid source event"
[[ "${QUBIX_SOURCE_SHA}" =~ ^[0-9a-f]{40}$ ]] || die "invalid source commit SHA"
[[ "${QUBIX_IMAGE_NAME}" =~ ^[a-z0-9][a-z0-9-]{0,127}$ ]] || die "invalid image name"
[[ "${QUBIX_IMAGE_TAG}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] || die "invalid image tag"
[[ "${QUBIX_IMAGE_DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]] || die "invalid image digest"
[[ "${QUBIX_FEDORA_VERSION}" =~ ^[0-9]{2}$ ]] || die "invalid Fedora version"
[[ "${QUBIX_ISO_VERSION}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,159}$ ]] || die "invalid ISO version"
[[ "${QUBIX_ISO_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*\.iso$ ]] || die "invalid ISO filename"
[[ "${QUBIX_CHECKSUM_NAME}" == "${QUBIX_ISO_NAME}-CHECKSUM" ]] || die "checksum filename does not match ISO"
[[ "${QUBIX_ISO_URL}" =~ ^https://[^[:space:]]+$ ]] || die "invalid OneDrive ISO URL"
[[ "${QUBIX_CHECKSUM_URL}" =~ ^https://[^[:space:]]+$ ]] || die "invalid OneDrive checksum URL"
[[ "${QUBIX_ISO_SHA256}" =~ ^[0-9a-f]{64}$ ]] || die "invalid ISO SHA-256"
[[ "${QUBIX_ISO_SIZE_BYTES}" =~ ^[1-9][0-9]*$ ]] || die "invalid ISO byte count"
[[ "${QUBIX_KEEP_VERSIONS}" =~ ^[1-9][0-9]*$ ]] || die "invalid retention count"
jq -e 'type == "array" and all(.[]; type == "string" and test("^v-[A-Za-z0-9][A-Za-z0-9_.-]{0,159}$"))' \
  <<< "${QUBIX_PURGED_VERSIONS}" >/dev/null || die "invalid purged-version list"

case "${QUBIX_ISO_VARIANT}" in
  standard) variant_title="Standard" ;;
  cachyos) variant_title="CachyOS" ;;
  nvidia) variant_title="NVIDIA" ;;
esac

case "${QUBIX_SOURCE_EVENT}" in
  schedule)
    [[ "${QUBIX_RETENTION_CHANNEL}" == "scheduled" ]] || die "scheduled event/channel mismatch"
    source_title="Scheduled"
    prerelease=false
    ;;
  push)
    [[ "${QUBIX_RETENTION_CHANNEL}" == "push" ]] || die "push event/channel mismatch"
    source_title="Push"
    prerelease=true
    ;;
  workflow_dispatch)
    [[ "${QUBIX_RETENTION_CHANNEL}" == "push" ]] || die "manual event/channel mismatch"
    source_title="Manual"
    prerelease=true
    ;;
esac

# ── Render the stable release title, tag, and reviewed Markdown body ────────────────────
# GitHub lists this non-semver release family by its tag identifier. Keep a fixed `z`
# sentinel ahead of the timestamp so new tags sort above legacy `iso-<variant>-...` tags
# while the timestamp itself remains the descending chronological key.
release_sort_timestamp="$(date -u '+%Y%m%d%H%M%S')"
release_date="${release_sort_timestamp:0:4}-${release_sort_timestamp:4:2}-${release_sort_timestamp:6:2}"
release_timestamp="${release_date} ${release_sort_timestamp:8:2}:${release_sort_timestamp:10:2}:${release_sort_timestamp:12:2} UTC"
release_tag="iso-z-${release_sort_timestamp}-${QUBIX_ISO_VARIANT}-${QUBIX_RETENTION_CHANNEL}-${QUBIX_ISO_VERSION}"
release_title="Qubix OS ${variant_title} ISO — Fedora ${QUBIX_FEDORA_VERSION} — ${source_title} — ${release_date}"
source_commit_url="${GITHUB_SERVER_URL}/${QUBIX_RELEASE_REPOSITORY}/commit/${QUBIX_SOURCE_SHA}"
workflow_run_url="${GITHUB_SERVER_URL}/${QUBIX_RELEASE_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
iso_size_gib="$(awk -v bytes="${QUBIX_ISO_SIZE_BYTES}" 'BEGIN { printf "%.2f GiB", bytes / 1073741824 }')"

{
  printf '# Qubix OS %s installer\n\n' "${variant_title}"
  printf '## Download\n\n'
  printf '| ISO | SHA-256 |\n'
  printf '|---|---|\n'
  printf '| [Download `%s` from OneDrive](%s) | `%s` |\n\n' \
    "${QUBIX_ISO_NAME}" "${QUBIX_ISO_URL}" "${QUBIX_ISO_SHA256}"
  printf '[Download the checksum file](%s)\n\n' "${QUBIX_CHECKSUM_URL}"
  printf '> The ISO is hosted on Microsoft OneDrive because it is too large for GitHub '
  printf 'artifact storage. The link remains available while this version is retained.\n\n'
  printf '## Build information\n\n'
  printf '| Property | Value |\n'
  printf '|---|---|\n'
  printf '| Variant | %s |\n' "${variant_title}"
  printf '| Fedora release | %s |\n' "${QUBIX_FEDORA_VERSION}"
  printf '| Architecture | `x86_64` |\n'
  printf '| Installer type | Kinoite |\n'
  printf '| Image tag | `%s` |\n' "${QUBIX_IMAGE_TAG}"
  printf '| Source trigger | %s |\n' "${source_title}"
  printf '| Published at | %s |\n' "${release_timestamp}"
  printf '| Source commit | [`%s`](%s) |\n' "${QUBIX_SOURCE_SHA:0:12}" "${source_commit_url}"
  printf '| ISO workflow | [Run %s, attempt %s](%s) |\n' \
    "${GITHUB_RUN_ID}" "${GITHUB_RUN_ATTEMPT}" "${workflow_run_url}"
  printf '| ISO size | %s (%s bytes) |\n\n' "${iso_size_gib}" "${QUBIX_ISO_SIZE_BYTES}"
  printf '## Verified source image\n\n'
  printf '`ghcr.io/qubik65536/%s@%s`\n\n' "${QUBIX_IMAGE_NAME}" "${QUBIX_IMAGE_DIGEST}"
  printf 'The source image signature was verified with the repository `cosign.pub` key '
  printf 'before its immutable digest was embedded in the installer.\n\n'
  printf '## Verify the download\n\n'
  printf '```bash\nsha256sum -c %s\n```\n\n' "${QUBIX_CHECKSUM_NAME}"
  printf 'On macOS:\n\n'
  printf '```bash\nshasum -a 256 -c %s\n```\n\n' "${QUBIX_CHECKSUM_NAME}"
  printf '## Retention\n\n'
  if [[ "${QUBIX_RETENTION_CHANNEL}" == "scheduled" ]]; then
    printf 'This is a **scheduled official release**. The newest %s scheduled versions '
    printf 'of this variant are retained.\n\n' "${QUBIX_KEEP_VERSIONS}"
  else
    printf 'This is a **push/manual prerelease**. The newest %s push/manual versions '
    printf 'of this variant are retained.\n\n' "${QUBIX_KEEP_VERSIONS}"
  fi
  printf 'Generated ISO releases more than three calendar months old are also removed '
  printf 'on a best-effort basis.\n'
} > "${work_dir}/release-body.md"

jq -n \
  --arg tag_name "${release_tag}" \
  --arg target_commitish "${QUBIX_SOURCE_SHA}" \
  --arg name "${release_title}" \
  --rawfile body "${work_dir}/release-body.md" \
  --argjson prerelease "${prerelease}" \
  '{tag_name: $tag_name, target_commitish: $target_commitish, name: $name, body: $body, draft: false, prerelease: $prerelease, generate_release_notes: false}' \
  > "${work_dir}/release-request.json"

# ── Publish first; a valid installer without a release is a failed workflow outcome ─────
gh api --method POST "/repos/${QUBIX_RELEASE_REPOSITORY}/releases" \
  --input "${work_dir}/release-request.json" > "${work_dir}/release-response.json" \
  || die "cannot create GitHub Release ${release_tag}"
release_url="$(jq -er '.html_url' "${work_dir}/release-response.json")" \
  || die "GitHub did not return the published release URL"

{
  printf 'release-url=%s\n' "${release_url}"
  printf 'release-tag=%s\n' "${release_tag}"
} >> "${GITHUB_OUTPUT}"
echo "Published GitHub Release ${release_tag}: ${release_url}"

# ── Remove records whose OneDrive targets were just permanently purged ────────────────
while IFS= read -r purged_name; do
  [[ -n "${purged_name}" ]] || continue
  purged_version="${purged_name#v-}"
  delete_release_for_version "${purged_version}"
done < <(jq -r '.[]' <<< "${QUBIX_PURGED_VERSIONS}")

# ── Best-effort three-calendar-month GitHub release retention ─────────────────────────
# This catches old generated release records even if their OneDrive cleanup happened in a
# previous run. It accepts the timestamp-prefixed family and the legacy
# `iso-<variant>-<channel>-` family, but never targets another tag.
cutoff_epoch="$(date -u --date='3 months ago' '+%s')" || {
  warn "cannot calculate the three-month release cutoff"
  exit 0
}
if ! gh api --paginate "/repos/${QUBIX_RELEASE_REPOSITORY}/releases?per_page=100" \
  --jq '.[] | [.tag_name, .published_at] | @tsv' > "${work_dir}/releases"; then
  warn "cannot list GitHub Releases for age retention"
  exit 0
fi

while IFS=$'\t' read -r old_tag published_at; do
  [[ "${old_tag}" =~ ^iso-(z-[0-9]{14}-)?(standard|cachyos|nvidia)-(scheduled|push)-[A-Za-z0-9][A-Za-z0-9_.-]{0,159}$ ]] \
    || continue
  if ! published_epoch="$(date -u --date="${published_at}" '+%s' 2>/dev/null)"; then
    warn "cannot parse publication time for ${old_tag}"
    continue
  fi
  if (( published_epoch < cutoff_epoch )); then
    delete_release_and_tag "${old_tag}"
  fi
done < "${work_dir}/releases"
