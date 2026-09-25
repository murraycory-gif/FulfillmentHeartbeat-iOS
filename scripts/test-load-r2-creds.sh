#!/bin/sh
# Credential lookup without printing secret values.
set -eu
cd "$(dirname "$0")/.."
# shellcheck source=scripts/load-r2-creds.sh
. ./scripts/load-r2-creds.sh

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

reset_creds() {
  unset R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export R2_ENV_FILE="$HOME/.config/heartbeat/r2.env"
mkdir -p "$HOME/.config/heartbeat" "$tmp/bin"
export PATH="$tmp/bin:$PATH"

cat > "$tmp/bin/security" <<'EOF'
#!/bin/sh
acct=""
while [ $# -gt 0 ]; do
  case "$1" in
    -a) acct=$2; shift 2 ;;
    *) shift ;;
  esac
done
case "$acct" in
  access_key_id) printf '%s\n' key-from-chain ;;
  secret_access_key) printf '%s\n' secret-from-chain ;;
  account_id) exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/security"

reset_creds
fill_r2_from_keychain
[ "$(r2_cred_value R2_ACCESS_KEY_ID)" = "key-from-chain" ] || fail "keychain access key"
[ "$(r2_cred_value R2_SECRET_ACCESS_KEY)" = "secret-from-chain" ] || fail "keychain secret"
[ -z "$(r2_cred_value R2_ACCOUNT_ID)" ] || fail "missing account should stay empty"

printf '%s\n' 'R2_ACCOUNT_ID="acct-from-file"' '# comment' 'OTHER=no' > "$R2_ENV_FILE"
fill_r2_from_env_file
[ "$(r2_cred_value R2_ACCOUNT_ID)" = "acct-from-file" ] || fail "env file account"
[ "$(r2_cred_value R2_ACCESS_KEY_ID)" = "key-from-chain" ] || fail "env file must not replace keychain"

reset_creds
export R2_ACCESS_KEY_ID=from-env
load_r2_credentials
[ "$(r2_cred_value R2_ACCESS_KEY_ID)" = "from-env" ] || fail "environment wins"
[ "$(r2_cred_value R2_SECRET_ACCESS_KEY)" = "secret-from-chain" ] || fail "keychain fills secret"
[ "$(r2_cred_value R2_ACCOUNT_ID)" = "acct-from-file" ] || fail "file fills account"

reset_creds
rm -f "$R2_ENV_FILE"
mv "$tmp/bin/security" "$tmp/bin/security.off"
if load_r2_credentials >"$tmp/out" 2>"$tmp/err"; then
  fail "expected missing credentials"
fi
grep -q "Missing R2 credentials: R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID" "$tmp/err" || fail "missing names"
grep -q "heartbeat-r2" "$tmp/err" || fail "keychain hint"
grep -q "setup-r2-keychain.sh" "$tmp/err" || fail "setup hint"
! grep -q "key-from-chain" "$tmp/err" || fail "error leaked a value"

echo "load-r2-creds ok"
