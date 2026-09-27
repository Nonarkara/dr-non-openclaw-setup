# 00 — Quickstart

> A Mac (or a Linux machine with a normal user session) ends this page with a
> gateway on `127.0.0.1:18789`, exec policy `cautious` or `deny-all`, and no
> channel until you decide to add one.

Commands here were checked against **OpenClaw 2026.9.6**. If `openclaw <command> --help` disagrees, believe the binary.

The two scripts in this repo are the path. They are idempotent. They exit non-zero when a check fails. They do not invent tokens, and they do not set `yolo`.

| Script | What it does | Exit codes |
|---|---|---|
| [`bin/doctor`](../bin/doctor) | Reads the machine. Prints `[ ok ]`, `[warn]`, `[FAIL]`. | 0 green, 2 warnings, 1 failure |
| [`bin/bootstrap`](../bin/bootstrap) | Installs the CLI if needed, sets the policy you name, pins loopback. | 1 if the baseline is not safe |

---

## 0. Requirements

| Need | Floor | Notes |
|---|---|---|
| OS | macOS, or Linux with a user session | Mac uses launchd. Linux uses systemd `--user`. A container with neither can still run `openclaw gateway run` in the foreground. |
| Node.js | **24.16+** (26 recommended) | Node 20 and 22 are too old. Install with nvm or fnm. Do not `sudo npm`. |
| Disk | about **10 GB** free on `/` | On a Mac, swap shares the boot volume. A full disk looks like a model bug. |
| Docker or Podman | strongly recommended | Without it, sandboxing is unavailable and a command that runs can see the real filesystem. |
| Ollama | optional | Local models. See [`05-local-llm-16gb.md`](05-local-llm-16gb.md). |
| RAM | 8 GB to run the gateway, 16 GB if you want the models in that doc | The gateway itself is not the 12B model. |

---

## 1. See what is missing

From a clone of this repo:

```bash
./bin/doctor
```

Red means stop. Yellow means the gateway can exist but a limit is real (no Docker, nothing listening yet, no model credential). Green is the only line you treat as done.

Doctor reports whether `OPENCLAW_GATEWAY_TOKEN` and provider keys are **present**. It does not print the values.

---

## 2. Safe baseline — still no channel, still no invented token

```bash
./bin/bootstrap --policy cautious --skip-service
```

`cautious` asks before a shell command. If you only want conversation:

```bash
./bin/bootstrap --policy deny-all --skip-service
```

What this writes, under `~/.openclaw/` (not in this repo):

- exec policy matching the flag
- `gateway.mode=local`
- `gateway.bind=loopback`

What it will not do:

- set `yolo`
- bind `lan` or `0.0.0.0`
- loosen `deny-all` into `cautious` (that needs `--force-policy`)
- rewrite a bind you already set to something wider
- create a gateway token
- install a channel, an MCP server, or a skill

Re-run it. A matching policy and an existing loopback bind stay as they are.

---

## 3. You create the gateway token

The service cannot see a variable that exists only in your terminal. Put it in the daemon env file.

```bash
umask 077
mkdir -p ~/.openclaw
# type the token into this file yourself, one line:
#   OPENCLAW_GATEWAY_TOKEN=...
chmod 600 ~/.openclaw/.env
```

Or 1Password, using the committed template (references only):

```bash
umask 077
mkdir -p ~/.openclaw
op inject -i config/env.1password.example -o ~/.openclaw/.env
chmod 600 ~/.openclaw/.env
```

Then install the service:

```bash
./bin/bootstrap --policy cautious
```

If this machine has no launchd and no systemd user manager, bootstrap stops and says so. The baseline is still in place. Run the process in the foreground instead:

```bash
openclaw gateway run
```

That listens on loopback. It is not a public port.

---

## 4. A model, then prove the gateway

Cloud: you type the key. Prefer the step-by-step wizard over Quick start.

```bash
openclaw onboard --classic
```

Keep bind on loopback. Skip extra channels, extra MCP servers, and extra agents.

Local, after `ollama pull qwen3:4b` and with Ollama answering on `127.0.0.1:11434`:

```bash
./bin/bootstrap --policy cautious --onboard-local
```

That path is non-interactive, so upstream requires `--accept-risk`. The script still skips channels, skips skills, pins `--gateway-bind loopback`, and puts the exec policy back if onboard leaves it unsafe. The model id defaults to `qwen3:4b` (`--ollama-model` to override). Use an id `ollama list` actually shows.

Then:

```bash
./bin/doctor
openclaw gateway status
openclaw health
```

You want `bind=loopback` and `127.0.0.1`, typically port `18789`. `Connectivity probe: failed` with `ECONNREFUSED` means nothing is listening yet. A supervisor that says "running" is not the proof. The probe is.

`openclaw models scan` ranks OpenRouter's public free catalog. It is not local model discovery. For Ollama:

```bash
openclaw models list --provider ollama
openclaw models status
```

---

## 5. One channel, only after the doctor is boring

```bash
openclaw channels status
openclaw pairing list <channel>
openclaw devices list
```

Approve only a sender and a device you recognise. A stranger's DM should get a pairing code, not an action.

Send one message from your paired account and wait for a reply. If nothing arrives: `openclaw doctor`, then `openclaw status`, then `openclaw logs`, then `df -h /`. Do not loosen policy and do not add a second channel to see if that one works.

---

## Failure modes

| What you see | What it means | Do |
|---|---|---|
| `./bin/doctor` says node is older than 24.16 | The CLI's floor, not a suggestion | nvm or fnm. Do not `sudo npm` |
| `npm install` says EACCES | The global prefix is not yours | nvm or fnm. Do not sudo |
| doctor says exec policy is unsafe | Upstream default is `security=full`, `ask=off` | `./bin/bootstrap --policy cautious` |
| bootstrap refuses because bind is `lan` | Something already exposed the control plane | Read it. Set loopback yourself if that was a mistake. The script will not silently rewrite it |
| `No supported service manager` | No launchd / systemd `--user` | `openclaw gateway run` in the foreground, or install from a real login session |
| port status `free` | Nothing is listening | Service install, or `openclaw gateway run` |
| empty model reply, exit 0 | A reasoning model spent the budget on hidden thinking | `thinking: false` / `think: false`. See [`05-local-llm-16gb.md`](05-local-llm-16gb.md) |
| local model dies instantly | Disk (and therefore swap) is full | `df -h /` before you touch model settings |
| `models scan` does not show Ollama | That command is OpenRouter's free catalog | `openclaw models list --provider ollama` |
| phone cannot connect | The gateway is loopback on purpose | `openclaw devices list`, then approve the request id. Do not bind the LAN |

More operating failures: [`04-operating-it.md`](04-operating-it.md).

---

## Uninstall

```bash
openclaw uninstall    # service + local data; CLI remains
npm uninstall -g openclaw
```

Rotate every provider key and bot token it held. Deleting the software does not un-issue the credentials.
