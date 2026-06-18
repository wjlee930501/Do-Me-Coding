# Do-Me-Coding shared secret-path detector (v0.2).
# Sourced by worker-context-guard.sh. The `is_secret_path` function below is kept BYTE-IDENTICAL to
# the copy in .claude/hooks/secret-guard.sh (verified by an md5-identity check in verification) to
# prevent drift. Decides by path string only; never opens files.
is_secret_path() {
  p="$1"
  [ -n "$p" ] || return 1
  base="${p##*/}"
  # ALLOW (not secrets): example/sample env templates
  case "$base" in
    .env.example|.env.sample|.env.template|.env.dist) return 1 ;;
  esac
  # BLOCK: dot-env family (.env, .env.local, .env.prod.local, .env.production, ...)
  case "$base" in
    .env|.env.*) return 0 ;;
  esac
  # BLOCK: keys / certs / credential files
  case "$base" in
    *.pem|*.key|id_rsa|id_dsa|id_ecdsa|id_ed25519|*.p12|*.pfx|*.keystore|*.jks|.npmrc|.netrc|.pgpass|credentials.json|*service-account*.json) return 0 ;;
  esac
  # BLOCK: secret-typed config files
  case "$base" in
    *secret*.json|*secret*.yaml|*secret*.yml|*secret*.env|*secrets*.json|*secrets*.yaml|*secrets*.yml) return 0 ;;
  esac
  # BLOCK: well-known secret paths
  case "$p" in
    */.ssh/*|*/.aws/credentials|*/.gnupg/*) return 0 ;;
  esac
  return 1
}
