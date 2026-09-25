#!/bin/sh
# Fill R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_ACCOUNT_ID.
# Order: existing environment, macOS Keychain service heartbeat-r2, then
# ~/.config/heartbeat/r2.env (override with R2_ENV_FILE). Never prints values.
# Returns 0 when all three are set. On failure, prints the missing names.

keychain_account_for() {
  case "$1" in
    R2_ACCESS_KEY_ID) printf '%s\n' access_key_id ;;
    R2_SECRET_ACCESS_KEY) printf '%s\n' secret_access_key ;;
    R2_ACCOUNT_ID) printf '%s\n' account_id ;;
    *) return 1 ;;
  esac
}

r2_cred_value() {
  case "$1" in
    R2_ACCESS_KEY_ID) printf '%s' "${R2_ACCESS_KEY_ID:-}" ;;
    R2_SECRET_ACCESS_KEY) printf '%s' "${R2_SECRET_ACCESS_KEY:-}" ;;
    R2_ACCOUNT_ID) printf '%s' "${R2_ACCOUNT_ID:-}" ;;
    *) return 1 ;;
  esac
}

fill_r2_from_keychain() {
  command -v security >/dev/null 2>&1 || return 0
  var=""
  acct=""
  val=""
  for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID; do
    val=$(r2_cred_value "$var")
    if [ -n "$val" ]; then
      continue
    fi
    acct=$(keychain_account_for "$var")
    val=$(security find-generic-password -s heartbeat-r2 -a "$acct" -w 2>/dev/null || true)
    if [ -n "$val" ]; then
      export "$var=$val"
    fi
  done
}

apply_r2_env_line() {
  line=$1
  key=${line%%=*}
  val=${line#*=}
  case "$val" in
    \"*\") val=${val#\"}; val=${val%\"} ;;
    \'*\') val=${val#\'}; val=${val%\'} ;;
  esac
  case "$key" in
    R2_ACCESS_KEY_ID|R2_SECRET_ACCESS_KEY|R2_ACCOUNT_ID) ;;
    *) return 0 ;;
  esac
  if [ -z "$(r2_cred_value "$key")" ]; then
    export "$key=$val"
  fi
}

fill_r2_from_env_file() {
  file=${R2_ENV_FILE:-"$HOME/.config/heartbeat/r2.env"}
  [ -f "$file" ] || return 0
  line=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
    esac
    apply_r2_env_line "$line"
  done < "$file"
}

missing_r2_creds() {
  missing=""
  var=""
  val=""
  for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID; do
    val=$(r2_cred_value "$var")
    if [ -z "$val" ]; then
      missing="$missing $var"
    fi
  done
  printf '%s' "$missing"
}

load_r2_credentials() {
  fill_r2_from_keychain
  fill_r2_from_env_file
  missing=$(missing_r2_creds)
  if [ -z "$missing" ]; then
    return 0
  fi
  echo "Missing R2 credentials:$missing" >&2
  echo "Checked the environment, macOS Keychain service heartbeat-r2 (accounts access_key_id, secret_access_key, account_id), and ${R2_ENV_FILE:-$HOME/.config/heartbeat/r2.env}." >&2
  echo "Store them once with: ./scripts/setup-r2-keychain.sh" >&2
  return 1
}
