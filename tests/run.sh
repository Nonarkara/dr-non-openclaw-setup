#!/usr/bin/env bash
# Unit checks for doctor/bootstrap, plus a real OpenClaw baseline when Node 24 and the CLI exist.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOGIN_HOME="$HOME"
FIXTURE="$ROOT/tests/fixtures/openclaw"
chmod +x "$ROOT/bin/doctor" "$ROOT/bin/bootstrap" "$FIXTURE"

fail() { printf 'TEST FAIL: %s\n' "$*" >&2; exit 1; }

assert_exit() {
  local want="$1" got="$2" name="$3"
  if [[ "$got" -ne "$want" ]]; then
    fail "$name: exit $got, want $want"
  fi
}

assert_contains() {
  local file="$1" needle="$2" name="$3"
  if ! grep -q -F -- "$needle" "$file"; then
    fail "$name: missing [$needle]"
  fi
}

assert_not_contains() {
  local file="$1" needle="$2" name="$3"
  if grep -q -F -- "$needle" "$file"; then
    fail "$name: leaked [$needle]"
  fi
}

printf '== link check ==\n'
python3 - "$ROOT" <<'PY'
import os, re, sys
root = sys.argv[1]
link_re = re.compile(r"\[[^\]]*\]\(([^)]+)\)|src=\"([^\"]+)\"|href=\"([^\"]+)\"")
bad = []
for dirpath, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in (".git", "node_modules")]
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(dirpath, name)
        text = open(path, encoding="utf-8").read()
        for match in link_re.finditer(text):
            link = next(g for g in match.groups() if g)
            if link.startswith(("http://", "https://", "mailto:")):
                continue
            if link.startswith("#"):
                continue
            link = link.split("#", 1)[0].strip()
            if not link:
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(path), link))
            if not os.path.exists(target):
                bad.append(f"{os.path.relpath(path, root)} -> {link}")
if bad:
    print("\n".join(bad))
    sys.exit(1)
print("relative links and images resolve")
PY

new_case() {
  local name="$1"
  CASE="$(mktemp -d)"
  FIX="$CASE/fixture"
  mkdir -p "$FIX" "$CASE/home"
  printf 'unsafe\n' >"$FIX/policy"
  : >"$FIX/bind"
  printf 'missing\n' >"$FIX/token"
  printf 'free\n' >"$FIX/port"
  printf 'clean\n' >"$FIX/audit"
  printf 'ok\n' >"$FIX/service"
  export OPENCLAW_FIXTURE_DIR="$FIX"
  export OPENCLAW_FIXTURE_LOG="$CASE/log"
  : >"$OPENCLAW_FIXTURE_LOG"
  export OPENCLAW_BIN="$FIXTURE"
  export OPENCLAW_DOCTOR_NODE_VERSION="24.16.0"
  export OPENCLAW_DOCTOR_DOCKER="present"
  export OPENCLAW_DOCTOR_OLLAMA="up"
  export OPENCLAW_DOCTOR_DISK_FREE_KB="$((20 * 1024 * 1024))"
  export OPENCLAW_DOCTOR_SCAN_ROOT="$ROOT"
  export HOME="$CASE/home"
  unset OPENCLAW_GATEWAY_TOKEN ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY XAI_API_KEY GEMINI_API_KEY GROQ_API_KEY OLLAMA_API_KEY || true
  printf 'case %s\n' "$name"
}

printf '== doctor: green baseline ==\n'
new_case green
printf 'cautious\n' >"$FIX/policy"
printf 'loopback\n' >"$FIX/bind"
printf 'ref\n' >"$FIX/token"
printf 'busy\n' >"$FIX/port"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=fixture-token-value\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
# fixture writes config on first status/config call via existing file builder
"$FIXTURE" config file >/dev/null
set +e
"$ROOT/bin/doctor" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 0 "$rc" "green doctor"
assert_contains "$CASE/out" "all checks green" "green doctor"
assert_not_contains "$CASE/out" "fixture-token-value" "green doctor"

printf '== doctor: unsafe default policy ==\n'
new_case unsafe
printf 'loopback\n' >"$FIX/bind"
printf 'ref\n' >"$FIX/token"
printf 'busy\n' >"$FIX/port"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=fixture-token-value\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
"$FIXTURE" config file >/dev/null
set +e
"$ROOT/bin/doctor" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "unsafe policy"
assert_contains "$CASE/out" "exec policy is unsafe" "unsafe policy"

printf '== doctor: lan bind ==\n'
new_case lan
printf 'cautious\n' >"$FIX/policy"
printf 'lan\n' >"$FIX/bind"
printf 'ref\n' >"$FIX/token"
printf 'busy\n' >"$FIX/port"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=fixture-token-value\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
"$FIXTURE" config file >/dev/null
set +e
"$ROOT/bin/doctor" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "lan bind"
assert_contains "$CASE/out" "gateway bind is lan" "lan bind"

printf '== doctor: plaintext token is a failure and is not printed ==\n'
new_case plaintext
printf 'cautious\n' >"$FIX/policy"
printf 'loopback\n' >"$FIX/bind"
printf 'plaintext\n' >"$FIX/token"
printf 'busy\n' >"$FIX/port"
"$FIXTURE" config file >/dev/null
set +e
"$ROOT/bin/doctor" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "plaintext token"
assert_contains "$CASE/out" "raw string" "plaintext token"
assert_not_contains "$CASE/out" "PLAINTEXT_SHOULD_NOT_LEAK" "plaintext token"
assert_not_contains "$CASE/err" "PLAINTEXT_SHOULD_NOT_LEAK" "plaintext token stderr"

printf '== doctor: old node ==\n'
new_case oldnode
export OPENCLAW_DOCTOR_NODE_VERSION="22.14.0"
printf 'cautious\n' >"$FIX/policy"
printf 'loopback\n' >"$FIX/bind"
printf 'ref\n' >"$FIX/token"
printf 'busy\n' >"$FIX/port"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=fixture-token-value\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
"$FIXTURE" config file >/dev/null
set +e
"$ROOT/bin/doctor" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "old node"
assert_contains "$CASE/out" "older than 24.16" "old node"

printf '== doctor: committed secret scan ==\n'
new_case secretscan
printf 'cautious\n' >"$FIX/policy"
printf 'loopback\n' >"$FIX/bind"
printf 'ref\n' >"$FIX/token"
printf 'busy\n' >"$FIX/port"
mkdir -p "$HOME/.openclaw" "$CASE/scan"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=fixture-token-value\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
secret_body="$(python3 -c 'print("a"*26)')"
printf 'sk-%s\n' "$secret_body" >"$CASE/scan/notes.txt"
export OPENCLAW_DOCTOR_SCAN_ROOT="$CASE/scan"
"$FIXTURE" config file >/dev/null
set +e
"$ROOT/bin/doctor" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "secret scan"
assert_contains "$CASE/out" "credential-shaped" "secret scan"
assert_not_contains "$CASE/out" "$secret_body" "secret scan"

printf '== bootstrap: refuses yolo and a missing policy ==\n'
new_case yolo
set +e
"$ROOT/bin/bootstrap" --policy yolo >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "yolo flag"
assert_contains "$CASE/err" "refusing --policy yolo" "yolo flag"
assert_not_contains "$OPENCLAW_FIXTURE_LOG" "yolo" "yolo was not invoked"
set +e
"$ROOT/bin/bootstrap" >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "missing policy"

printf '== bootstrap: does not loosen deny-all ==\n'
new_case keepdeny
printf 'deny-all\n' >"$FIX/policy"
set +e
"$ROOT/bin/bootstrap" --policy cautious --skip-service >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "keep deny-all"
assert_contains "$CASE/err" "already deny-all" "keep deny-all"
[[ "$(tr -d '\n' <"$FIX/policy")" == "deny-all" ]] || fail "deny-all was rewritten"

printf '== bootstrap: wires a ref, refuses service without ~/.openclaw/.env ==\n'
new_case wire
export OPENCLAW_GATEWAY_TOKEN="TOKENVALUE8838"
set +e
"$ROOT/bin/bootstrap" --policy cautious >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "service without env file"
[[ "$(tr -d '\n' <"$FIX/policy")" == "cautious" ]] || fail "policy not cautious"
[[ "$(tr -d '\n' <"$FIX/bind")" == "loopback" ]] || fail "bind not loopback"
[[ "$(tr -d '\n' <"$FIX/token")" == "ref" ]] || fail "token ref not stored"
assert_not_contains "$FIX/openclaw.json" "TOKENVALUE8838" "config leaked token"
assert_not_contains "$CASE/out" "TOKENVALUE8838" "stdout leaked token"
assert_not_contains "$CASE/err" "TOKENVALUE8838" "stderr leaked token"
assert_not_contains "$OPENCLAW_FIXTURE_LOG" "preset yolo" "no yolo preset"
assert_contains "$CASE/out" "service not installed" "service gate"

printf '== bootstrap: service installs once the env file exists ==\n'
new_case service
export OPENCLAW_GATEWAY_TOKEN="TOKENVALUE8838"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=TOKENVALUE8838\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
set +e
"$ROOT/bin/bootstrap" --policy cautious >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 0 "$rc" "service install"
assert_contains "$OPENCLAW_FIXTURE_LOG" "gateway install --runtime node" "install invoked"
assert_not_contains "$CASE/out" "TOKENVALUE8838" "service stdout"
assert_contains "$CASE/out" "gateway service install returned success" "service success"

printf '== bootstrap: no service manager is a loud failure ==\n'
new_case nosvc
printf 'none\n' >"$FIX/service"
export OPENCLAW_GATEWAY_TOKEN="TOKENVALUE8838"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=TOKENVALUE8838\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
set +e
"$ROOT/bin/bootstrap" --policy cautious >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "no service manager"
assert_contains "$CASE/out" "no launchd or systemd" "no service manager"
assert_contains "$CASE/out" "Baseline config and exec policy are in place" "partial explained"

printf '== bootstrap: local onboard stays on loopback and skips channels ==\n'
new_case onboard
printf 'cautious\n' >"$FIX/policy"
printf 'loopback\n' >"$FIX/bind"
printf 'ref\n' >"$FIX/token"
mkdir -p "$HOME/.openclaw"
umask 077
printf 'OPENCLAW_GATEWAY_TOKEN=TOKENVALUE8838\n' >"$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"
printf '{"models":[{"name":"qwen3:4b"}]}\n' >"$CASE/tags.json"
export OPENCLAW_BOOTSTRAP_OLLAMA_TAGS="$CASE/tags.json"
export OPENCLAW_GATEWAY_TOKEN="TOKENVALUE8838"
set +e
"$ROOT/bin/bootstrap" --policy cautious --skip-service --onboard-local >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 0 "$rc" "onboard local"
assert_contains "$OPENCLAW_FIXTURE_LOG" "--gateway-bind loopback" "onboard bind"
assert_contains "$OPENCLAW_FIXTURE_LOG" "--skip-channels" "onboard channels"
assert_contains "$OPENCLAW_FIXTURE_LOG" "--auth-choice ollama" "onboard ollama"
assert_not_contains "$OPENCLAW_FIXTURE_LOG" "yolo" "onboard yolo"

printf '== bootstrap: refuses to rewrite a lan bind ==\n'
new_case keeplan
printf 'cautious\n' >"$FIX/policy"
printf 'lan\n' >"$FIX/bind"
set +e
"$ROOT/bin/bootstrap" --policy cautious --skip-service >"$CASE/out" 2>"$CASE/err"
rc=$?
set -e
assert_exit 1 "$rc" "keep lan"
[[ "$(tr -d '\n' <"$FIX/bind")" == "lan" ]] || fail "lan bind was rewritten"
assert_contains "$CASE/err" "gateway.bind is 'lan'" "keep lan message"

NODE24="${OPENCLAW_NODE24_BIN:-$LOGIN_HOME/.local/node-v24.16.0-linux-x64/bin}"

if [[ -x "$NODE24/openclaw" && -x "$NODE24/node" ]]; then
  printf '== live OpenClaw baseline in a throwaway HOME ==\n'
  LIVE="$(mktemp -d)"
  export HOME="$LIVE/home"
  export PATH="$NODE24:$PATH"
  unset OPENCLAW_BIN OPENCLAW_DOCTOR_NODE_VERSION OPENCLAW_DOCTOR_DOCKER OPENCLAW_DOCTOR_OLLAMA OPENCLAW_DOCTOR_DISK_FREE_KB OPENCLAW_DOCTOR_SCAN_ROOT OPENCLAW_BOOTSTRAP_OLLAMA_TAGS OPENCLAW_GATEWAY_TOKEN || true
  mkdir -p "$HOME"
  token="live-token-should-not-print-8838"
  umask 077
  mkdir -p "$HOME/.openclaw"
  printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$token" >"$HOME/.openclaw/.env"
  chmod 600 "$HOME/.openclaw/.env"
  export OPENCLAW_GATEWAY_TOKEN="$token"
  set +e
  "$ROOT/bin/bootstrap" --policy cautious --skip-service >"$LIVE/boot.out" 2>"$LIVE/boot.err"
  brc=$?
  set -e
  assert_exit 0 "$brc" "live bootstrap"
  cfg="$HOME/.openclaw/openclaw.json"
  [[ -f "$cfg" ]] || fail "live config missing"
  assert_not_contains "$cfg" "$token" "live config"
  assert_not_contains "$LIVE/boot.out" "$token" "live bootstrap stdout"
  assert_not_contains "$LIVE/boot.err" "$token" "live bootstrap stderr"
  python3 - "$cfg" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
gw = data["gateway"]
assert gw["mode"] == "local", gw
assert gw["bind"] == "loopback", gw
token = gw["auth"]["token"]
assert isinstance(token, dict), type(token)
assert token["source"] == "env" and token["id"] == "OPENCLAW_GATEWAY_TOKEN", token
print("live config shape ok")
PY
  set +e
  "$ROOT/bin/doctor" >"$LIVE/doc.out" 2>"$LIVE/doc.err"
  drc=$?
  set -e
  # Gateway is not running and Docker/Ollama may be absent, so warnings are expected.
  # A failure here means policy, bind, or a leaked secret.
  if [[ "$drc" -eq 1 ]]; then
    cat "$LIVE/doc.out" "$LIVE/doc.err" >&2
    fail "live doctor returned a hard failure"
  fi
  assert_not_contains "$LIVE/doc.out" "$token" "live doctor stdout"
  assert_contains "$LIVE/doc.out" "loopback" "live doctor bind"
  assert_contains "$LIVE/doc.out" "cautious" "live doctor policy"
  printf 'live doctor exit %s (0 green, 2 warnings allowed)\n' "$drc"
  rm -rf "$LIVE"
else
  printf '== live OpenClaw baseline skipped (CLI not installed) ==\n'
fi

printf 'all tests passed\n'
