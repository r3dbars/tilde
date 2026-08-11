#!/usr/bin/env bash
# Shared, strict signing-identity selection for local development bundles.

tilde_resolve_signing_identity_from_details() {
  local requested="$1"
  local details="$2"
  local matches count

  matches="$(printf '%s\n' "$details" | awk -v wanted="$requested" '
    function valid_hash(value) {
      return length(value) == 40 && value ~ /^[[:xdigit:]]+$/
    }
    $1 ~ /^[0-9]+\)$/ && valid_hash($2) && /"[^"]+"[[:space:]]*$/ {
      name = $0
      sub(/^[^"]*"/, "", name)
      sub(/"[[:space:]]*$/, "", name)
      if (wanted == "") {
        if (name ~ /^Apple Development: .+ \([[:alnum:]]+\)$/) print toupper($2)
      } else if (toupper(wanted) == toupper($2) || wanted == name) {
        print toupper($2)
      }
    }
  ' | LC_ALL=C sort -u)"
  count="$(printf '%s\n' "$matches" | awk 'NF { count++ } END { print count + 0 }')"

  if [[ "$count" == "1" ]]; then
    printf '%s\n' "$matches"
  elif [[ -n "$requested" ]]; then
    [[ "$count" == "0" ]] && echo "signing identity is unavailable: $requested" >&2 \
      || echo "signing identity is ambiguous: $requested; pass its exact SHA-1" >&2
    return 1
  else
    [[ "$count" == "0" ]] \
      && echo "no eligible Apple Development identity found; use --sign-identity - only for explicit ad hoc builds" >&2 \
      || echo "multiple eligible Apple Development identities found; pass one exact SHA-1 with --sign-identity" >&2
    return 1
  fi
}

tilde_resolve_signing_identity() {
  local requested="$1"
  local details
  if [[ "$requested" == "-" ]]; then
    echo "warning: ad hoc bundles cannot exercise the authenticated app-to-IME runtime" >&2
    printf '%s\n' '-'
    return
  fi
  details="$(security find-identity -p codesigning -v 2>/dev/null)" \
    || { echo "could not read eligible code-signing identities" >&2; return 1; }
  tilde_resolve_signing_identity_from_details "$requested" "$details"
}

tilde_signing_identity_selftest() {
  local apple_hash='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
  local other_apple_hash='BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
  local developer_id_hash='CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
  local one two selected warning
  one="  1) $apple_hash \"Apple Development: Tilde Dev (TEAMID1234)\"
  2) $developer_id_hash \"Developer ID Application: Tilde Dev (TEAMID1234)\""
  two="$one
  3) $other_apple_hash \"Apple Development: Other Dev (OTHERID123)\""

  selected="$(tilde_resolve_signing_identity_from_details '' "$one")"
  [[ "$selected" == "$apple_hash" ]] || return 1
  selected="$(tilde_resolve_signing_identity_from_details "$developer_id_hash" "$one")"
  [[ "$selected" == "$developer_id_hash" ]] || return 1
  selected="$(tilde_resolve_signing_identity_from_details 'Apple Development: Tilde Dev (TEAMID1234)' "$one")"
  [[ "$selected" == "$apple_hash" ]] || return 1
  selected="$(tilde_resolve_signing_identity '-' 2>/dev/null)"
  [[ "$selected" == '-' ]] || return 1
  warning="$(tilde_resolve_signing_identity '-' 2>&1 >/dev/null)"
  [[ "$warning" == 'warning: ad hoc bundles cannot exercise the authenticated app-to-IME runtime' ]] || return 1
  ! tilde_resolve_signing_identity_from_details '' "$two" >/dev/null 2>&1 || return 1
  ! tilde_resolve_signing_identity_from_details '' '0 valid identities found' >/dev/null 2>&1 || return 1
  ! tilde_resolve_signing_identity_from_details 'Tilde Dev' "$one" >/dev/null 2>&1 || return 1
  echo "selftest OK: local signing selects one exact Apple Development identity and fails closed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  [[ "${1:-}" == "--selftest" && "$#" == "1" ]] \
    || { echo "Usage: script/signing_identity.sh --selftest" >&2; exit 2; }
  tilde_signing_identity_selftest
fi
