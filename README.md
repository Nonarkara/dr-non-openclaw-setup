<p align="center">
  <img src="docs/hero-banner.png" alt="Hand-drawn manga illustration of a Bangkok civic studio at night: one wooden desk, a glass-domed gateway machine under a stone arch, a closed padlock and key, a mentor and a learner, small red lobster helpers. Illustration only — not a live UI or screenshot." width="100%">
</p>
<p align="center"><em>One desk, one machine, a gateway that asks before it acts. The method is public; the keys stay in your pocket.</em></p>

# Dr Non's OpenClaw Set-Up

**A self-hosted [OpenClaw](https://docs.openclaw.ai/) gateway, set up so a competent person can run it — useful, and safe by default.**

[![License: MIT](https://img.shields.io/github/license/Nonarkara/dr-non-openclaw-setup?color=1A1A1A)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/checked%20against-OpenClaw%202026.9.6-1A1A1A)](https://docs.openclaw.ai/)

By [Non Arkaraprasertkul](https://github.com/Nonarkara) (Nonarkara) — architect, urban anthropologist, and founder of **[Axiom X Co., Ltd.](https://axiom.nonarkara.org)**, a one-desk civic studio in Bangkok.

This repository is independent studio writing plus two scripts (`bin/doctor`, `bin/bootstrap`). It is **not** an official depa, ASEAN, municipal, xAI, or Cursor product. OpenClaw is upstream software. There is no hosted gateway URL here. You run it on **your** machine.

**ไทย / English.** The studio audience is bilingual. This README and the docs are English-first so a fork can follow the CLI. Keep Thai in the work you do with the agent.

**CLI names drift.** These commands were checked against OpenClaw **2026.9.6**. When a flag here disagrees with the binary, believe `openclaw <command> --help`.

---

## What this is

A field guide and a safe baseline for the OpenClaw **gateway**: one long-lived process on your computer that can sit between a chat channel, a model, and — if you allow it — a shell.

Day-to-day at this studio runs on **Grok Bot** (a Cursor-backed desktop assistant). This repo stays because forks still want the self-hosted gateway: channels, device pairing, exec policy, and a loopback control plane. It maps the desk jobs a Grok-shaped workflow needs. It does not claim to be Grok Bot, Cursor, or xAI's product.

| If you want… | Go here |
|---|---|
| A gateway on your machine, one chat channel, tools behind an exec policy | **This repo** |
| A bot that answers from a knowledge folder, or a local multi-bot / council orchestrator | [diy-rag-chatbot](https://github.com/Nonarkara/diy-rag-chatbot) |
| The desktop assistant with cloud coding agents | Grok Bot / Cursor — not this tree |
| Obsidian memory as files | [second-brain-os](https://github.com/Nonarkara/second-brain-os), after the gateway is boring |

**This repo is not** a fork of OpenClaw, a place to file upstream bugs, a live demo, a credential store, or a second copy of the RAG orchestrator.

---

## What you need

| | Floor |
|---|---|
| Machine | Mac, or Linux with a real user session (launchd or systemd `--user`) |
| Node.js | **24.16+**. 26 is what upstream recommends. **20 and 22 are too old.** Use nvm or fnm. Do not `sudo npm`. |
| Disk | About **10 GB** free on `/`. A full boot volume breaks local models in ways that look like model bugs. |
| Docker or Podman | Strongly recommended. Without it there is no sandbox, and a command that runs can see the real disk. |
| Ollama | Optional. Model picks for 16 GB: [`docs/05-local-llm-16gb.md`](docs/05-local-llm-16gb.md). |
| Secrets | You type them, or `op inject` from [`config/env.1password.example`](config/env.1password.example). Nothing in git is a real key. |

---

## Quickstart

Clone this repo, then:

```bash
./bin/doctor
./bin/bootstrap --policy cautious --skip-service
```

Doctor prints `[ ok ]`, `[warn]`, and `[FAIL]`. Exit **0** is all green, **2** is warnings, **1** is stop. Bootstrap refuses `yolo`, refuses a non-loopback bind, and refuses to invent a token.

Create the gateway token yourself (the service cannot see a shell export):

```bash
umask 077
mkdir -p ~/.openclaw
# one line, you type the value:  OPENCLAW_GATEWAY_TOKEN=...
chmod 600 ~/.openclaw/.env

./bin/bootstrap --policy cautious
./bin/doctor
openclaw gateway status
```

You want a listener on **`127.0.0.1:18789`**. `port.status` `free`, or `ECONNREFUSED`, means nothing is up yet.

Then a model — you type any cloud key in `openclaw onboard --classic`, or `./bin/bootstrap --policy cautious --onboard-local` after `ollama pull qwen3:4b`. Then **one** channel, and `openclaw pairing list <channel>` before you trust a reply.

Conversation only, no shell: `--policy deny-all`.

The long version, including Linux without a service manager: [`docs/00-quickstart.md`](docs/00-quickstart.md).

An agent can do the tedious parts. Paste:

```
Set up OpenClaw on my machine following
https://github.com/Nonarkara/dr-non-openclaw-setup
```

It follows [`AGENTS.md`](AGENTS.md). It does not type credentials, does not set `yolo`, and does not bind past `127.0.0.1`.

---

## Threat model, in one screen

OpenClaw is valuable because it sits on your messages, your models, and your machine at the same time. That is also the risk.

| # | What can go wrong | How this starts you |
|---|---|---|
| 1 | A webpage, PDF, or stranger DM talks the agent into a shell command | Exec policy `cautious` or `deny-all` **before** any channel. Never `yolo`. Upstream's untouched default is full access. |
| 2 | Anyone who finds the bot can put text in front of the agent | `openclaw pairing list` / `approve` |
| 3 | The control plane is reachable beyond this desk | Bind `127.0.0.1`. A phone uses device pairing, not an open port. |
| 4 | Keys land in git, logs, or a screenshot | SecretRefs and `~/.openclaw/.env` (mode 600). Doctor checks presence, not values. |
| 5 | An allowed command can still see the whole disk | Docker/Podman sandbox. If it is missing, doctor says so. |
| 6 | A loop spends money while you sleep | Local models for routine work. Look at the bill. |

The page to read before the first inbound DM is [`docs/03-security.md`](docs/03-security.md).

A message becomes an action only if pairing **and** policy allow it. Diagrams: [`diagrams/`](diagrams/).

---

## When something fails

Do not debug by loosening security.

| Symptom | Look here | Do not |
|---|---|---|
| doctor: node older than 24.16 | nvm or fnm | `sudo npm`, or pinning an old OpenClaw and hoping |
| `npm install` says EACCES | nvm/fnm so your user owns the prefix | `sudo npm install -g` |
| doctor: exec policy unsafe | `./bin/bootstrap --policy cautious` | `exec-policy preset yolo` |
| bootstrap: bind is `lan` | You, or a previous wizard, exposed it | Leave it "so the phone can connect" |
| `No supported service manager` | Mac login session, or Linux `systemd --user` | Binding `0.0.0.0` |
| `gateway status` probe `ECONNREFUSED` | Nothing is listening. `openclaw gateway run`, or install the service | Adding a second channel |
| Empty model reply, exit 0 | Reasoning model. Turn thinking off | Assuming the model is broken |
| Local model dies instantly | `df -h /` | Tweaking temperature |
| `models scan` does not list Ollama | That command is OpenRouter's free catalog | Pasting an OpenRouter key to "make scan work" |
| Phone says pairing required | `openclaw devices list`, then `approve <requestId>` | Opening port 18789 |

Stuck: report the exact command, the exact output, and what you have ruled out. [`docs/04-operating-it.md`](docs/04-operating-it.md) is the longer list of quiet failures.

---

## What's in this tree

| Path | What it is |
|---|---|
| [`bin/doctor`](bin/doctor) | Green / yellow / red check of Node, disk, policy, loopback, auth presence |
| [`bin/bootstrap`](bin/bootstrap) | Idempotent install and safe baseline. No secrets written |
| [`config/openclaw.example.json5`](config/openclaw.example.json5) | Gateway shape. Not copied over your live config |
| [`config/env.1password.example`](config/env.1password.example) | `op://` references for `op inject` |
| [`AGENTS.md`](AGENTS.md) | The same order, for an agent, with stops that are yours |
| [`docs/00-quickstart.md`](docs/00-quickstart.md) | Human quickstart, Mac and Linux |
| [`docs/01-what-you-are-installing.md`](docs/01-what-you-are-installing.md) | Capabilities you are granting |
| [`docs/02-architecture.md`](docs/02-architecture.md) | Message path and gates |
| [`docs/03-security.md`](docs/03-security.md) | Threat model and hardening |
| [`docs/04-operating-it.md`](docs/04-operating-it.md) | Health checks that don't lie |
| [`docs/05-local-llm-16gb.md`](docs/05-local-llm-16gb.md) | Which local model, and why the RAM number lies |
| [`docs/06-essential-tool-calls.md`](docs/06-essential-tool-calls.md) | Tools by risk tier |
| [`docs/07-grok-bot-parity.md`](docs/07-grok-bot-parity.md) | Which desk jobs OpenClaw can mirror |
| [`docs/08-gateway-config.md`](docs/08-gateway-config.md) | Providers, tools, connectors, health |
| [`diagrams/`](diagrams/) | Message path, security layers, first week |
| [`tests/run.sh`](tests/run.sh) | Script tests, plus a throwaway-HOME live baseline when the CLI is installed |

Going further: operate it ([`docs/04-operating-it.md`](docs/04-operating-it.md)), then tools ([`docs/06-essential-tool-calls.md`](docs/06-essential-tool-calls.md)), then the Grok-shaped desk ([`docs/07-grok-bot-parity.md`](docs/07-grok-bot-parity.md)).

---

## Philosophy

**Fork the method, not the secrets.** The order is survey, policy, loopback, one channel. Provider keys and bot tokens are not in this tree.

**One machine.** Not a cluster and not a public tunnel. Bind `127.0.0.1`.

**No fake green.** Doctor's exit code matches the lines it printed. A health check that returns success while doing nothing useful is a lie.

**ไทย / English as the audience.** The README stays English-first so a fork can run the CLI without guessing.

Company: **Axiom X Co., Ltd.** Author: **Non Arkaraprasertkul** ([Nonarkara](https://github.com/Nonarkara)).

Ethical use, short form: a gateway you own, pairing required, loopback only, no `yolo`, no keys in git, no implication that a government or Axiom X operates the learner's bot. The longer form is the old field-guide standard in [`docs/03-security.md`](docs/03-security.md).

---

## License / contributing

[MIT](LICENSE). SPDX: `MIT`. Copyright © 2026 **Non Arkaraprasertkul / Axiom X Co., Ltd.**

The license covers **this repository**. It does not relicense OpenClaw, model weights, chat platforms, or anyone else's credentials.

Corrections welcome, against `main`. Do not add live tokens, private paths, or a second channel to make a demo richer. Do not weaken a rule in `AGENTS.md` to make a step easier. Verify with `./tests/run.sh`.

*Fork the method. Keep the keys. Bind loopback.*
