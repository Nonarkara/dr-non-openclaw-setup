# Shared helpers for bin/doctor and bin/bootstrap.
# Test-only environment variables (do not set these to hide a real failure):
#   OPENCLAW_DOCTOR_NODE_VERSION   e.g. 24.16.0
#   OPENCLAW_DOCTOR_DISK_FREE_KB
#   OPENCLAW_DOCTOR_DOCKER         present|missing
#   OPENCLAW_DOCTOR_OLLAMA         present|missing|up|down
#   OPENCLAW_DOCTOR_SCAN_ROOT
#   OPENCLAW_BIN

if [[ -z "${OPENCLAW_LIB_LOADED:-}" ]]; then
  OPENCLAW_LIB_LOADED=1
fi

ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW="${OPENCLAW_BIN:-openclaw}"
FAILS=0
WARNS=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  DIM=""
  RESET=""
fi

pass() { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
fail() { FAILS=$((FAILS + 1)); printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*"; }
warn() { WARNS=$((WARNS + 1)); printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$*"; }
info() { printf '%s[info]%s %s\n' "$DIM" "$RESET" "$*"; }
next_step() { printf '       next: %s\n' "$*"; }

die() {
  printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$*" >&2
  exit 1
}

redact_stream() {
  local text="$1"
  if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
    text="${text//${OPENCLAW_GATEWAY_TOKEN}/[redacted]}"
  fi
  printf '%s\n' "$text" | sed -E \
    -e 's/sk-[A-Za-z0-9_-]{8,}/[redacted]/g' \
    -e 's/ghp_[A-Za-z0-9]{8,}/[redacted]/g' \
    -e 's/gho_[A-Za-z0-9]{8,}/[redacted]/g' \
    -e 's/github_pat_[A-Za-z0-9_]{8,}/[redacted]/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{8,}/[redacted]/g'
}

node_version_raw() {
  if [[ -n "${OPENCLAW_DOCTOR_NODE_VERSION:-}" ]]; then
    printf '%s\n' "${OPENCLAW_DOCTOR_NODE_VERSION#v}"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1; then
    return 1
  fi
  local v
  v="$(node --version 2>/dev/null || true)"
  v="${v#v}"
  if [[ -z "$v" ]]; then
    return 1
  fi
  printf '%s\n' "$v"
}

version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, A, "."); split(b, B, ".");
    for (i = 1; i <= 3; i++) {
      ai = A[i] + 0; bi = B[i] + 0;
      if (ai > bi) exit 0;
      if (ai < bi) exit 1;
    }
    exit 0;
  }'
}

disk_free_kb() {
  if [[ -n "${OPENCLAW_DOCTOR_DISK_FREE_KB:-}" ]]; then
    printf '%s\n' "$OPENCLAW_DOCTOR_DISK_FREE_KB"
    return 0
  fi
  df -kP / | awk 'NR==2 {print $4}'
}

docker_state() {
  if [[ -n "${OPENCLAW_DOCTOR_DOCKER:-}" ]]; then
    printf '%s\n' "$OPENCLAW_DOCTOR_DOCKER"
    return 0
  fi
  if command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1; then
    printf 'present\n'
  else
    printf 'missing\n'
  fi
}

ollama_state() {
  if [[ -n "${OPENCLAW_DOCTOR_OLLAMA:-}" ]]; then
    printf '%s\n' "$OPENCLAW_DOCTOR_OLLAMA"
    return 0
  fi
  if ! command -v ollama >/dev/null 2>&1; then
    printf 'missing\n'
    return 0
  fi
  if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    printf 'up\n'
  else
    printf 'down\n'
  fi
}

ram_gb() {
  if [[ -r /proc/meminfo ]]; then
    awk '/MemTotal/ {printf "%.0f\n", $2/1024/1024}' /proc/meminfo
    return 0
  fi
  if command -v sysctl >/dev/null 2>&1; then
    local bytes
    bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
    if [[ -n "$bytes" ]]; then
      awk -v b="$bytes" 'BEGIN {printf "%.0f\n", b/1073741824}'
      return 0
    fi
  fi
  return 1
}

file_mode() {
  local f="$1" mode
  if mode="$(stat -c %a "$f" 2>/dev/null)"; then
    printf '%s\n' "$mode"
    return 0
  fi
  stat -f %Lp "$f"
}

# Prints missing|empty|placeholder|op-ref|present. Never prints the value.
env_file_value_kind() {
  local file="$1" key="$2"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const key = process.argv[2];
    if (!fs.existsSync(file)) { process.stdout.write("missing"); process.exit(0); }
    const text = fs.readFileSync(file, "utf8");
    let found = false;
    let kind = "missing";
    for (const line of text.split(/\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const body = trimmed.startsWith("export ") ? trimmed.slice(7) : trimmed;
      if (!body.startsWith(key + "=")) continue;
      found = true;
      let val = body.slice(key.length + 1).trim();
      if ((val.startsWith("\"") && val.endsWith("\"")) || (val.startsWith("'\''") && val.endsWith("'\''"))) {
        val = val.slice(1, -1);
      }
      if (!val) kind = "empty";
      else if (val.startsWith("op://")) kind = "op-ref";
      else if (/^(replace-me|changeme|todo|your-token|xxx)$/i.test(val)) kind = "placeholder";
      else kind = "present";
    }
    process.stdout.write(found ? kind : "missing");
  ' "$file" "$key"
}

shell_var_set() {
  local key="$1"
  [[ -n "${!key:-}" ]]
}

policy_fields() {
  node -e '
    let raw = "";
    process.stdin.on("data", (d) => { raw += d; });
    process.stdin.on("end", () => {
      let d;
      try { d = JSON.parse(raw); }
      catch (err) { process.stdout.write("unparsed|||"); return; }
      const s = (((d.effectivePolicy || {}).scopes) || [])[0] || {};
      const sec = (s.security || {}).effective || "";
      const ask = (s.ask || {}).effective || "";
      const fb = (s.askFallback || {}).effective || "";
      let kind = "unknown";
      if (sec === "full" || fb === "full") kind = "unsafe";
      else if (sec === "deny") kind = "deny-all";
      else if (sec === "allowlist" && (ask === "on-miss" || ask === "always") && fb === "deny") kind = "cautious";
      process.stdout.write([kind, sec, ask, fb].join("|"));
    });
  '
}

gateway_status_fields() {
  node -e '
    let raw = "";
    process.stdin.on("data", (d) => { raw += d; });
    process.stdin.on("end", () => {
      let d;
      try { d = JSON.parse(raw); }
      catch (err) { process.stdout.write("unparsed"); return; }
      const g = d.gateway || {};
      const port = d.port || {};
      const cfg = ((d.config || {}).cli) || {};
      const svc = d.service || {};
      const listeners = Array.isArray(port.listeners) ? port.listeners : [];
      const exposed = listeners.some((item) => {
        const blob = JSON.stringify(item);
        return blob.includes("0.0.0.0") || blob.includes("\"*\"") || blob.includes("[::]");
      });
      process.stdout.write([
        g.bindMode || "",
        g.bindHost || "",
        String(g.port || ""),
        port.status || "",
        cfg.exists === true ? "yes" : "no",
        cfg.valid === false ? "no" : "yes",
        svc.inspectionReason || "",
        ((svc.runtime || {}).status) || "",
        exposed ? "yes" : "no"
      ].join("|"));
    });
  '
}

config_auth_fields() {
  local file="$1"
  node -e '
    (function () {
    const fs = require("fs");
    const file = process.argv[1];
    if (!file || !fs.existsSync(file)) {
      process.stdout.write("missing-file");
      return;
    }
    let d;
    try { d = JSON.parse(fs.readFileSync(file, "utf8")); }
    catch (err) { process.stdout.write("unparsed"); return; }
    const gw = d.gateway || {};
    const auth = gw.auth || {};
    const token = auth.token;
    let tokenKind = "missing";
    let refSource = "";
    let refId = "";
    if (typeof token === "string") tokenKind = "plaintext";
    else if (token && typeof token === "object") {
      tokenKind = "ref";
      refSource = token.source || "";
      refId = token.id || "";
    }
    process.stdout.write([
      gw.mode || "",
      gw.bind || "",
      auth.mode || "",
      tokenKind,
      refSource,
      refId
    ].join("|"));
    })();
  ' "$file"
}

scan_tree_for_secrets() {
  local root="$1"
  local matches
  matches="$(grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' \
    --exclude='*.webp' --exclude='*.gif' \
    'sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}' \
    "$root" 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    fail "credential-shaped string under ${root}"
    printf '%s\n' "$matches" | awk -F: 'NF >= 2 {print "       " $1 ":" $2 " (match redacted)"}'
    return 1
  fi
  pass "no credential-shaped strings in ${root}"
  return 0
}

finish() {
  local what="$1"
  printf '\n'
  if [[ "$FAILS" -gt 0 ]]; then
    printf '%snot ready:%s %s — %d failed, %d warning(s)\n' "$RED" "$RESET" "$what" "$FAILS" "$WARNS"
    exit 1
  fi
  if [[ "$WARNS" -gt 0 ]]; then
    printf '%snot green:%s %s — 0 failed, %d warning(s). Read the lines above.\n' "$YELLOW" "$RESET" "$what" "$WARNS"
    exit 2
  fi
  printf '%sready:%s %s — all checks green\n' "$GREEN" "$RESET" "$what"
  exit 0
}
