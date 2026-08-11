#!/usr/bin/env bash
# Strict signing selection shared by the two development bundle builders.
tilde_resolve_signing_identity_from_details() {
  local requested="$1" match status
  [[ -z "$requested" || (${#requested} -eq 40 && "$requested" =~ ^[[:xdigit:]]+$) ]] \
    || { echo "--sign-identity must be an exact 40-character SHA-1" >&2; return 2; }
  if match="$(printf '%s\n' "$2" | awk -v wanted="$requested" '
    function valid_hash(value) { return length(value) == 40 && value ~ /^[[:xdigit:]]+$/ }
    function add(value) { if (!seen[value]++) { selected = value; count++ } }
    $1 ~ /^[0-9]+\)$/ && valid_hash($2) && /"[^"]+"[[:space:]]*$/ {
      hash = toupper($2)
      name = $0; sub(/^[^"]*"/, "", name); sub(/"[[:space:]]*$/, "", name)
      if (wanted != "" && hash == toupper(wanted)) add(hash)
      if (wanted == "" && name ~ /^Apple Development: .+ \([[:alnum:]]+\)$/) add(hash)
    }
    END { if (count == 1) print selected; else exit count == 0 ? 10 : 11 }
  ')"; then
    printf '%s\n' "$match"
    return
  fi
  status=$?
  if [[ -n "$requested" ]]; then
    echo "signing identity is unavailable: $requested" >&2
  elif [[ "$status" == "10" ]]; then
    echo "no eligible Apple Development identity found; use --sign-identity - only for explicit ad hoc builds" >&2
  else
    echo "multiple eligible Apple Development identities found; pass one exact SHA-1 with --sign-identity" >&2
  fi
  return 1
}
tilde_resolve_signing_identity() {
  if [[ "$1" == "-" ]]; then
    echo "warning: ad hoc bundles cannot exercise the authenticated app-to-IME runtime" >&2
    printf '%s\n' '-'
    return
  fi
  local details
  details="$(security find-identity -p codesigning -v 2>/dev/null)" \
    || { echo "could not read eligible code-signing identities" >&2; return 1; }
  tilde_resolve_signing_identity_from_details "$1" "$details"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  [[ "${1:-}" == "--selftest" && "$#" == "1" ]] || exit 2
  a='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'; b='BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
  d='CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
  one="1) $a \"Apple Development: Tilde Dev (TEAMID1234)\""$'\n'"2) $d \"Developer ID Application: Tilde Dev (TEAMID1234)\""
  [[ "$(tilde_resolve_signing_identity_from_details '' "$one")" == "$a" ]]
  [[ "$(tilde_resolve_signing_identity_from_details "$d" "$one")" == "$d" ]]
  ! tilde_resolve_signing_identity_from_details '' "$one"$'\n'"3) $b \"Apple Development: Other (OTHERID123)\"" >/dev/null 2>&1
  ! tilde_resolve_signing_identity_from_details '' '0 valid identities found' >/dev/null 2>&1
  ! tilde_resolve_signing_identity_from_details 'Tilde Dev' "$one" >/dev/null 2>&1
  [[ "$(tilde_resolve_signing_identity '-' 2>&1)" == $'warning: ad hoc bundles cannot exercise the authenticated app-to-IME runtime\n-' ]]
  echo "selftest OK: local signing selects one exact Apple Development identity and fails closed"
fi
