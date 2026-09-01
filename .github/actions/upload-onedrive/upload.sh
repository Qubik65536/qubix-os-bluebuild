#!/usr/bin/env bash
# Upload a Qubix ISO/checksum pair to a Microsoft 365 work/school OneDrive.
#
# GitHub OIDC is exchanged for an app-only Microsoft Graph token. Files first land in a
# staging directory, which is renamed into the retained trigger-channel set only after both
# sizes verify. Retention permanently deletes complete version directories beyond the
# configured channel count; it never puts multi-gigabyte ISOs into the recycle bin.

set -euo pipefail

readonly GRAPH_ROOT="https://graph.microsoft.com/v1.0"
readonly TOKEN_AUDIENCE="api://AzureADTokenExchange"
readonly CHUNK_UNIT=327680
readonly CHUNK_UNITS=160
readonly CHUNK_SIZE=$((CHUNK_UNIT * CHUNK_UNITS))

work_dir="$(mktemp -d)"
graph_token=""
drive_id=""
staging_folder_id=""
version_is_committed=0
active_upload_url=""

# ── Error cleanup ─────────────────────────────────────────────────────────────
# Cancel an unfinished upload session and permanently remove only the directory created by
# this invocation. A renamed `v-*` remains rollback-owned until retention also succeeds.
cleanup() {
  local exit_status=$?

  if (( exit_status != 0 )); then
    if [[ -n "${active_upload_url}" ]]; then
      curl --silent --show-error --request DELETE "${active_upload_url}" >/dev/null || true
    fi
    if [[ -n "${graph_token}" && -n "${drive_id}" && -n "${staging_folder_id}" && "${version_is_committed}" == 0 ]]; then
      curl --silent --show-error --request POST \
        --header "Authorization: Bearer ${graph_token}" \
        "${GRAPH_ROOT}/drives/${drive_id}/items/${staging_folder_id}/permanentDelete" \
        >/dev/null || true
    fi
  fi

  rm -rf "${work_dir}"
  exit "${exit_status}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

die() {
  echo "onedrive-upload: $*" >&2
  exit 1
}

require_value() {
  local variable_name=$1
  [[ -n "${!variable_name:-}" ]] || die "${variable_name} is required"
}

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

# Fetch a fresh run-scoped GitHub assertion and exchange it for a Graph access token. The
# same function is used if a long ISO transfer outlives the first access token.
acquire_graph_token() {
  local oidc_separator='?'
  local oidc_response
  local oidc_token
  local token_response

  [[ "${ACTIONS_ID_TOKEN_REQUEST_URL}" == *\?* ]] && oidc_separator='&'
  if ! oidc_response="$(curl --fail --silent --show-error --retry 5 --retry-all-errors \
    --header "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}${oidc_separator}audience=$(urlencode "${TOKEN_AUDIENCE}")")"; then
    die "cannot request a GitHub OIDC token"
  fi
  oidc_token="$(jq -er '.value' <<< "${oidc_response}")" \
    || die "GitHub OIDC response did not contain a token"
  echo "::add-mask::${oidc_token}"

  if ! token_response="$(curl --fail --silent --show-error --retry 5 --retry-all-errors \
    --request POST \
    --data-urlencode "client_id=${ONEDRIVE_CLIENT_ID}" \
    --data-urlencode 'scope=https://graph.microsoft.com/.default' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode 'client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer' \
    --data-urlencode "client_assertion=${oidc_token}" \
    "https://login.microsoftonline.com/${ONEDRIVE_TENANT_ID}/oauth2/v2.0/token")"; then
    die "cannot exchange GitHub OIDC with Microsoft Entra"
  fi
  graph_token="$(jq -er '.access_token' <<< "${token_response}")" \
    || die "Microsoft Entra response did not contain a Graph token"
  echo "::add-mask::${graph_token}"
}

graph_error_message() {
  jq -r '.error.message // .error_description // "Microsoft Graph request failed"' \
    "${work_dir}/graph-response" 2>/dev/null || echo "Microsoft Graph request failed"
}

# Send an authenticated Graph request and retain its response body for the caller. Expected
# 404/409 results are handled by the folder helper; every other non-2xx status fails closed.
graph_request() {
  local method=$1
  local url=$2
  local body=${3:-}
  local status
  local curl_status
  local auth_attempt=1
  local -a arguments

  while (( auth_attempt <= 2 )); do
    arguments=(
      --silent --show-error
      --request "${method}"
      --header "Authorization: Bearer ${graph_token}"
      --header "Accept: application/json"
      --output "${work_dir}/graph-response"
      --write-out '%{http_code}'
    )
    if [[ -n "${body}" ]]; then
      arguments+=(--header 'Content-Type: application/json' --data "${body}")
    fi

    set +e
    status="$(curl "${arguments[@]}" "${url}")"
    curl_status=$?
    set -e
    [[ ${curl_status} -eq 0 ]] || die "network failure calling Microsoft Graph"

    GRAPH_STATUS="${status}"
    if [[ "${status}" =~ ^2[0-9][0-9]$ ]]; then
      return 0
    fi
    if [[ "${status}" == 401 && ${auth_attempt} -eq 1 ]]; then
      acquire_graph_token
      auth_attempt=2
      continue
    fi
    return 1
  done
}

# Find or create a folder below a known parent item. Controlled Qubix names are addressed
# by path, while subsequent mutation uses opaque item IDs returned by Graph.
ensure_folder() {
  local parent_id=$1
  local folder_name=$2
  local encoded_parent
  local encoded_name
  local request_body

  encoded_parent="$(urlencode "${parent_id}")"
  encoded_name="$(urlencode "${folder_name}")"
  if graph_request GET "${drive_base}/items/${encoded_parent}:/${encoded_name}?%24select=id%2Cname%2Cfolder%2CparentReference"; then
    jq -e '.folder != null and (.id | type == "string")' "${work_dir}/graph-response" >/dev/null \
      || die "${folder_name} exists in OneDrive but is not a folder"
  elif [[ "${GRAPH_STATUS}" == 404 ]]; then
    request_body="$(jq -cn --arg name "${folder_name}" '{name: $name, folder: {}, "@microsoft.graph.conflictBehavior": "fail"}')"
    if ! graph_request POST "${drive_base}/items/${encoded_parent}/children" "${request_body}"; then
      # Another job may have created a shared parent between the GET and POST.
      if [[ "${GRAPH_STATUS}" != 409 ]] || \
         ! graph_request GET "${drive_base}/items/${encoded_parent}:/${encoded_name}?%24select=id%2Cname%2Cfolder%2CparentReference"; then
        die "cannot create OneDrive folder ${folder_name}: $(graph_error_message)"
      fi
    fi
    jq -e '.folder != null and (.id | type == "string")' "${work_dir}/graph-response" >/dev/null \
      || die "Graph did not return a folder for ${folder_name}"
  else
    die "cannot inspect OneDrive folder ${folder_name}: $(graph_error_message)"
  fi

  folder_id="$(jq -er '.id' "${work_dir}/graph-response")"
  folder_drive_id="$(jq -er '.parentReference.driveId' "${work_dir}/graph-response")"
}

# A staging directory is unique to one run attempt and must never be adopted from an older
# failed run. Failing on a name conflict keeps cleanup from touching somebody else's item.
create_staging_folder() {
  local parent_id=$1
  local folder_name=$2
  local encoded_parent
  local request_body

  encoded_parent="$(urlencode "${parent_id}")"
  request_body="$(jq -cn --arg name "${folder_name}" '{name: $name, folder: {}, "@microsoft.graph.conflictBehavior": "fail"}')"
  graph_request POST "${drive_base}/items/${encoded_parent}/children" "${request_body}" \
    || die "cannot create unique OneDrive staging folder ${folder_name}: $(graph_error_message)"
  jq -e '.folder != null and (.id | type == "string")' "${work_dir}/graph-response" >/dev/null \
    || die "Graph did not return the staging folder ${folder_name}"
  staging_folder_id="$(jq -er '.id' "${work_dir}/graph-response")"
  drive_id="$(jq -er '.parentReference.driveId' "${work_dir}/graph-response")"
}

# Confirm the destination file exists only after Graph reports the exact local byte count.
verify_remote_size() {
  local parent_id=$1
  local filename=$2
  local expected_size=$3
  local encoded_parent
  local encoded_name
  local remote_size

  encoded_parent="$(urlencode "${parent_id}")"
  encoded_name="$(urlencode "${filename}")"
  graph_request GET "${drive_base}/items/${encoded_parent}:/${encoded_name}?%24select=id%2Cname%2Csize%2Cfile" \
    || die "cannot verify uploaded file ${filename}: $(graph_error_message)"
  remote_size="$(jq -er '.size' "${work_dir}/graph-response")"
  [[ "${remote_size}" == "${expected_size}" ]] \
    || die "uploaded size mismatch for ${filename}: local=${expected_size}, remote=${remote_size}"
}

remote_size_matches() {
  local parent_id=$1
  local filename=$2
  local expected_size=$3
  local encoded_parent
  local encoded_name
  local remote_size

  encoded_parent="$(urlencode "${parent_id}")"
  encoded_name="$(urlencode "${filename}")"
  graph_request GET "${drive_base}/items/${encoded_parent}:/${encoded_name}?%24select=size" \
    || return 1
  remote_size="$(jq -er '.size' "${work_dir}/graph-response")" || return 1
  [[ "${remote_size}" == "${expected_size}" ]]
}

# Query a preauthenticated session after a failed/ambiguous PUT. This is what makes a
# transfer resume from Graph's accepted boundary instead of blindly replaying a range.
query_upload_offset() {
  local total_size=$1
  local status
  local curl_status
  local next_offset

  set +e
  status="$(curl --silent --show-error \
    --request GET \
    --output "${work_dir}/upload-status" \
    --write-out '%{http_code}' \
    "${active_upload_url}")"
  curl_status=$?
  set -e
  [[ ${curl_status} -eq 0 && "${status}" == 200 ]] || return 1

  next_offset="$(jq -er '.nextExpectedRanges[0] | split("-")[0] | tonumber' "${work_dir}/upload-status")" \
    || return 1
  (( next_offset >= 0 && next_offset <= total_size )) || return 1
  if (( next_offset != total_size && next_offset % CHUNK_UNIT != 0 )); then
    return 1
  fi
  upload_next_offset="${next_offset}"
}

# Upload through a resumable Graph session. Fifty-MiB fragments are below Graph's 60-MiB
# maximum and are an exact multiple of its mandatory 320-KiB boundary.
upload_file() {
  local parent_id=$1
  local local_path=$2
  local filename
  local encoded_parent
  local encoded_name
  local request_body
  local total_size
  local offset=0
  local remaining
  local expected_length
  local actual_length
  local range_end
  local status
  local curl_status
  local attempt
  local next_offset

  filename="$(basename "${local_path}")"
  encoded_parent="$(urlencode "${parent_id}")"
  encoded_name="$(urlencode "${filename}")"
  total_size="$(stat --format='%s' "${local_path}")"
  (( total_size > 0 )) || die "refusing to upload empty file ${local_path}"

  request_body="$(jq -cn --arg name "${filename}" '{item: {name: $name, "@microsoft.graph.conflictBehavior": "fail"}}')"
  graph_request POST "${drive_base}/items/${encoded_parent}:/${encoded_name}:/createUploadSession" "${request_body}" \
    || die "cannot create upload session for ${filename}: $(graph_error_message)"
  active_upload_url="$(jq -er '.uploadUrl' "${work_dir}/graph-response")"
  echo "Uploading ${filename} ($((total_size / 1024 / 1024)) MiB) to OneDrive"

  while (( offset < total_size )); do
    remaining=$((total_size - offset))
    expected_length=${CHUNK_SIZE}
    (( remaining < expected_length )) && expected_length=${remaining}

    dd if="${local_path}" of="${work_dir}/chunk" bs=${CHUNK_UNIT} \
      skip=$((offset / CHUNK_UNIT)) count=${CHUNK_UNITS} status=none
    actual_length="$(stat --format='%s' "${work_dir}/chunk")"
    [[ "${actual_length}" == "${expected_length}" ]] \
      || die "failed to prepare upload range at byte ${offset} for ${filename}"
    range_end=$((offset + actual_length - 1))

    attempt=1
    while (( attempt <= 5 )); do
      set +e
      status="$(curl --silent --show-error \
        --request PUT \
        --header "Content-Length: ${actual_length}" \
        --header "Content-Range: bytes ${offset}-${range_end}/${total_size}" \
        --header 'Content-Type: application/octet-stream' \
        --data-binary "@${work_dir}/chunk" \
        --output "${work_dir}/upload-response" \
        --write-out '%{http_code}' \
        "${active_upload_url}")"
      curl_status=$?
      set -e

      if [[ ${curl_status} -eq 0 && "${status}" =~ ^20[01]$ ]]; then
        offset=${total_size}
        break
      fi
      if [[ ${curl_status} -eq 0 && "${status}" == 202 ]]; then
        next_offset="$(jq -er '.nextExpectedRanges[0] | split("-")[0] | tonumber' "${work_dir}/upload-response")" \
          || die "Graph omitted the next range for ${filename}"
        (( next_offset > offset && next_offset <= total_size )) \
          || die "Graph returned an invalid next range for ${filename}"
        if (( next_offset != total_size && next_offset % CHUNK_UNIT != 0 )); then
          die "Graph returned a non-aligned next range for ${filename}"
        fi
        offset=${next_offset}
        break
      fi

      if query_upload_offset "${total_size}"; then
        if (( upload_next_offset > offset )); then
          offset=${upload_next_offset}
          break
        fi
      fi
      # The final PUT can commit successfully even if its response is lost. In that one
      # case the session may already be gone, so accept only an exact remote-size match.
      if remote_size_matches "${parent_id}" "${filename}" "${total_size}"; then
        offset=${total_size}
        break
      fi
      if (( attempt == 5 )); then
        die "upload stalled for ${filename} at byte ${offset} (HTTP ${status:-000})"
      fi
      sleep $((attempt * 2))
      attempt=$((attempt + 1))
    done
  done

  active_upload_url=""
  verify_remote_size "${parent_id}" "${filename}" "${total_size}"
}

# List every complete `v-*` directory, following Graph pagination, then permanently delete
# entries after the newest N. Staging folders are deliberately outside the retention set.
purge_old_versions() {
  local variant_id=$1
  local keep_count=$2
  local next_url
  local version_count
  local item_id
  local item_name

  : > "${work_dir}/versions"
  next_url="${GRAPH_ROOT}/drives/${drive_id}/items/${variant_id}/children?%24select=id%2Cname%2CcreatedDateTime%2Cfolder&%24top=200"
  while [[ -n "${next_url}" ]]; do
    graph_request GET "${next_url}" || die "cannot list OneDrive versions: $(graph_error_message)"
    jq -r '.value[] | select(.folder != null and (.name | startswith("v-"))) | [.createdDateTime, .name, .id] | @tsv' \
      "${work_dir}/graph-response" >> "${work_dir}/versions"
    next_url="$(jq -r '."@odata.nextLink" // empty' "${work_dir}/graph-response")"
  done

  sort -r -k1,1 -k2,2 "${work_dir}/versions" > "${work_dir}/versions-sorted"
  version_count="$(wc -l < "${work_dir}/versions-sorted" | tr -d ' ')"
  if (( version_count <= keep_count )); then
    echo "OneDrive retention: ${version_count}/${keep_count} complete ${QUBIX_ISO_VARIANT}/${QUBIX_RETENTION_CHANNEL} versions retained"
    return 0
  fi

  awk -v keep="${keep_count}" 'NR > keep { print $3 "\t" $2 }' "${work_dir}/versions-sorted" |
    while IFS=$'\t' read -r item_id item_name; do
      graph_request POST "${GRAPH_ROOT}/drives/${drive_id}/items/${item_id}/permanentDelete" \
        || die "cannot permanently purge OneDrive version ${item_name}: $(graph_error_message)"
      echo "Permanently purged OneDrive version ${QUBIX_ISO_VARIANT}/${QUBIX_RETENTION_CHANNEL}/${item_name}"
    done

  echo "OneDrive retention: ${keep_count}/${keep_count} complete ${QUBIX_ISO_VARIANT}/${QUBIX_RETENTION_CHANNEL} versions retained"
}

# ── Validate action inputs ────────────────────────────────────────────────────
for required_name in \
  ONEDRIVE_TENANT_ID ONEDRIVE_CLIENT_ID ONEDRIVE_USER_ID \
  QUBIX_ISO_VARIANT QUBIX_RETENTION_CHANNEL QUBIX_ISO_VERSION \
  QUBIX_ISO_PATH QUBIX_CHECKSUM_PATH \
  QUBIX_KEEP_VERSIONS ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN; do
  require_value "${required_name}"
done

guid_pattern='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
[[ "${ONEDRIVE_TENANT_ID}" =~ ${guid_pattern} ]] || die "ONEDRIVE_TENANT_ID must be a GUID"
[[ "${ONEDRIVE_CLIENT_ID}" =~ ${guid_pattern} ]] || die "ONEDRIVE_CLIENT_ID must be a GUID"
[[ "${QUBIX_ISO_VARIANT}" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] || die "invalid Qubix ISO variant"
[[ "${QUBIX_RETENTION_CHANNEL}" =~ ^(scheduled|push)$ ]] || die "invalid retention channel"
[[ "${QUBIX_ISO_VERSION}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,159}$ ]] || die "invalid Qubix ISO version"
[[ "${QUBIX_KEEP_VERSIONS}" =~ ^[1-9][0-9]*$ ]] || die "keep-versions must be a positive integer"
[[ -f "${QUBIX_ISO_PATH}" ]] || die "ISO not found: ${QUBIX_ISO_PATH}"
[[ -f "${QUBIX_CHECKSUM_PATH}" ]] || die "checksum not found: ${QUBIX_CHECKSUM_PATH}"
command -v curl >/dev/null && command -v jq >/dev/null && command -v dd >/dev/null \
  || die "curl, jq, and dd are required"

# ── Exchange GitHub OIDC for Microsoft Graph access ──────────────────────────
acquire_graph_token

# ── Create the staging hierarchy and upload both files ───────────────────────
encoded_user="$(urlencode "${ONEDRIVE_USER_ID}")"
drive_base="${GRAPH_ROOT}/users/${encoded_user}/drive"
graph_request GET "${drive_base}/root?%24select=id%2Cname%2Cfolder%2CparentReference" \
  || die "cannot access the configured Microsoft 365 OneDrive: $(graph_error_message)"
root_id="$(jq -er '.id' "${work_dir}/graph-response")"

ensure_folder "${root_id}" "Qubix-OS"
qubix_folder_id="${folder_id}"
drive_id="${folder_drive_id}"
ensure_folder "${qubix_folder_id}" "ISOs"
iso_folder_id="${folder_id}"
ensure_folder "${iso_folder_id}" "${QUBIX_ISO_VARIANT}"
variant_folder_id="${folder_id}"
ensure_folder "${variant_folder_id}" "${QUBIX_RETENTION_CHANNEL}"
channel_folder_id="${folder_id}"
create_staging_folder "${channel_folder_id}" ".upload-${QUBIX_ISO_VERSION}"

upload_file "${staging_folder_id}" "${QUBIX_ISO_PATH}"
upload_file "${staging_folder_id}" "${QUBIX_CHECKSUM_PATH}"

# ── Publish atomically and enforce channel retention ─────────────────────────
complete_name="v-${QUBIX_ISO_VERSION}"
rename_body="$(jq -cn --arg name "${complete_name}" '{name: $name}')"
graph_request PATCH "${GRAPH_ROOT}/drives/${drive_id}/items/${staging_folder_id}" "${rename_body}" \
  || die "cannot publish completed OneDrive version ${complete_name}: $(graph_error_message)"

purge_old_versions "${channel_folder_id}" "${QUBIX_KEEP_VERSIONS}"
version_is_committed=1
echo "Published OneDrive version ${QUBIX_ISO_VARIANT}/${QUBIX_RETENTION_CHANNEL}/${complete_name}"
