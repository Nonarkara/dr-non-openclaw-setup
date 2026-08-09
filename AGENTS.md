# AGENTS.md — Instructions for the AI agent doing this setup

> **You are an AI agent.** A human handed you this repository's URL and asked
> you to set up OpenClaw for them. This file tells you exactly what to do.
>
> Human reading this instead? You want [`README.md`](README.md). You can also
> just paste this repo's URL to Claude Code (or any capable agent) and say
> *"set this up for me"* — it will find this file and follow it.

---

## Your job

Install and configure OpenClaw on this machine so it is **useful and safe by
default**, then hand back a working system with a short report.

**Success looks like:** gateway running, one channel connected, exec policy at
`cautious` or stricter, `security audit` clean, local models installed and
matched to purpose, and the human knowing what they now have.

---

## Rules you must not break

These exist because the failure modes are expensive and quiet. Do not
"optimise" past them.

| # | Rule |
|---|---|
| 1 | **Never type a credential.** Not API keys, not tokens, not passwords. When one is needed, stop and ask the human to enter it themselves. |
| 2 | **Never set `exec-policy preset yolo`.** Not to fix an error, not to save a step. `cautious` is the floor. |
| 3 | **Never expose the gateway beyond `127.0.0.1`.** No port-forwarding, no public tunnels. Remote access is device pairing only. |
| 4 | **Never disable a security control to make something work.** If a step fails, diagnose it or report it. A blocked step is a finding, not an obstacle. |
| 5 | **Ask before installing anything not in this repo's plan** — extra MCP servers, extra skills, extra models. Each is a privilege grant. |
| 6 | **Verify after every step.** Run the check, read the output. A command exiting 0 is not evidence it worked. |
| 7 | **Stop and ask at every 🛑 marker.** Those are the human's decisions, not yours. |

---

## Before you start: read these

Read them fully before running anything. They contain the reasoning behind
every step below, and you will make better judgement calls with the context.

1. [`docs/01-what-you-are-installing.md`](docs/01-what-you-are-installing.md) — the capabilities being granted
2. [`docs/03-security.md`](docs/03-security.md) — threat model and hardening
3. [`docs/05-local-llm-16gb.md`](docs/05-local-llm-16gb.md) — model choice on constrained RAM

---

## Step 0 — Survey the machine

Do not assume. Gather facts first and report them.

```bash
# OS + hardware
uname -a
sysctl -n hw.memsize 2>/dev/null | awk '{printf "RAM: %.0f GB\n", $1/1073741824}'   # macOS
free -g 2>/dev/null | head -2                                                        # Linux

# Prerequisites
node --version          # need 20+
npm --version
docker --version        # optional but strongly recommended (sandboxing)
ollama --version        # optional (local models)

# Headroom
df -h /
```

**Report to the human:** OS, RAM, whether Node 20+ / Docker / Ollama are
present, and free disk.

🛑 **Stop if:** Node is below 20, or free disk is under ~10GB. Tell the human
what's missing rather than working around it. *(Low disk is not cosmetic — on
machines where swap shares the boot volume, a full disk makes local model
allocation fail in ways that look like model bugs.)*

---

## Step 1 — Install

```bash
npm install -g openclaw
openclaw --version
```

If a global install fails on permissions, **do not `sudo`.** Report it and
suggest a Node version manager (nvm/fnm), which fixes the cause.

---

## Step 2 — Lock down BEFORE connecting anything

Order matters. Set policy before the system can receive a message from the
outside world.

```bash
openclaw exec-policy preset cautious
openclaw exec-policy preset      # confirm what is now set
```

**Verify** the output says `cautious` (or `deny-all`). If it says anything
else, stop and report.

🛑 **Ask the human:** *"Should the agent be able to run shell commands at all?"*
- Wants it to run scripts / check services / build things → `cautious`
- Just wants a conversational assistant → `deny-all` (recommend this if unsure)

---

## Step 3 — Guided setup

```bash
openclaw onboard
```

This is interactive and will ask for credentials.

🛑 **Hand the keyboard to the human for every credential prompt.** Explain
what each one is for, then let them type it. Do not read keys from their
environment, their files, or their clipboard and paste them in.

If `onboard` isn't viable non-interactively, use `openclaw configure`, still
handing over for secrets.

---

## Step 4 — Local models (do this before wiring cloud providers)

Local models cost nothing per token, work offline, and give you a fallback
whose failure is genuinely independent of any cloud provider.

**Read [`docs/05-local-llm-16gb.md`](docs/05-local-llm-16gb.md) first** — model
choice depends on the RAM you measured in Step 0. On a 16GB machine:

```bash
# Embeddings — tiny, always worth having
ollama pull nomic-embed-text

# Fast general text: routing, summarising, drafting
ollama pull qwen3:4b

# Vision / multimodal (screenshots, photos, diagrams)
ollama pull gemma3:4b
```

Only pull a ~12B model if the machine has **≥16GB and few other apps running** —
see the doc for why that trade is tighter than it looks.

**Verify each model actually answers**, don't trust the pull:

```bash
curl -s http://127.0.0.1:11434/api/chat -d '{
  "model":"qwen3:4b","stream":false,"think":false,"keep_alive":0,
  "messages":[{"role":"user","content":"Reply with the single word: ready"}]
}' | python3 -c "import json,sys;print(json.load(sys.stdin)['message']['content'][:40])"
```

> `"think": false` is not optional on reasoning models. Without it they spend
> the whole token budget on hidden reasoning and return an **empty string with
> a success status**. `"keep_alive": 0` releases the model afterwards instead
> of pinning several GB for minutes.

Then register with OpenClaw:

```bash
openclaw models scan
openclaw models list
```

---

## Step 5 — Connect exactly one channel

```bash
openclaw channels
```

🛑 **Ask the human which channel** and let them authenticate it themselves.

**One channel first.** Confirm the whole path works before adding a second.

Then require approval for inbound strangers:

```bash
openclaw pairing        # inbound DM approval
openclaw devices        # paired devices
```

**Verify:** send a message from the connected app and confirm a reply. If
nothing arrives, `openclaw logs` and `openclaw doctor` before changing config.

---

## Step 6 — Sandbox anything touching untrusted content

If Docker is available:

```bash
openclaw sandbox list
openclaw sandbox explain     # the EFFECTIVE policy, not your intent
```

Read `explain` carefully — effective policy is the product of several layers,
and the surprise is rarely what you configured, it's what the layers combine
into.

If Docker is missing, say so plainly: *"Sandboxing is unavailable. The agent
can reach the real filesystem when it executes. Install Docker to contain it."*
Do not silently proceed as though it were equivalent.

---

## Step 7 — Audit

```bash
openclaw security audit
openclaw status
openclaw health
```

**Fix what the audit reports.** If a finding cannot be fixed without weakening
security, leave it and report it — do not trade the control away.

---

## Step 8 — Report back

Give the human a short, factual summary:

```markdown
## OpenClaw is set up

**Running:** gateway <status>, <N> channel(s), models <list>
**Exec policy:** <deny-all|cautious>  — <what that means in one line>
**Sandbox:** <enabled|unavailable — why it matters>
**Security audit:** <clean|findings>

**Local models installed**
| Model | Size | Use it for |
|---|---|---|
| ... | ... | ... |

**Try it:** <one concrete thing they can message the bot right now>

**Not done / needs you:**
- <anything requiring their credentials or a decision>

**Before going further, read:** docs/03-security.md
```

---

## If something breaks

In this order — each rules out everything above it:

```bash
openclaw doctor      # diagnoses and repairs most config/gateway/channel issues
openclaw status
openclaw logs
df -h /              # yes, really — check disk before debugging models
```

**Do not** fix a failure by loosening security. Common temptations, all wrong:
switching to `yolo` because a command was refused; binding the gateway to
`0.0.0.0` because a phone can't reach it (use pairing); disabling the sandbox
because a tool can't see a file (mount the path deliberately instead).

If you are stuck, report the exact command, the exact output, and what you have
ruled out. That is more useful than a workaround.

---

## Re-running this

Every step is idempotent. It is safe to run again to verify or repair an
existing install. Re-running never *loosens* configuration — if you find the
policy at `yolo`, set it back to `cautious` and tell the human you did.
