# 01 — What You Are Actually Installing

> Read this before `npm install -g openclaw`. Not to talk you out of it — to
> make sure you're saying yes to the real thing rather than to the word
> "assistant".

---

## The one-sentence version

OpenClaw installs a **persistent background service** that connects your chat
apps to AI models and, if you let it, to a **shell on your computer.**

Every clause there is a decision you are making. The maps:
[`diagrams/`](../diagrams/) — message path, security layers, first-week order.

---

## What arrives on your machine

| Component | What it does | Runs when |
|---|---|---|
| **CLI** (`openclaw`) | Configure, inspect, control | You invoke it |
| **Gateway service** | The always-on brain: routes messages, runs agents | **Continuously**, including after reboot |
| **Agent workspaces** | Per-agent state, auth, working directories | With the gateway |
| **Config + state dirs** | Credentials, sessions, memory, logs | Persist on disk |
| **Sandbox containers** *(optional)* | Docker isolation for execution | When sandboxing is on |

Roughly 51 direct dependencies, so a real `node_modules`. Nothing unusual for a
Node application — but it *is* a service, not a script you run and forget.

---

## The four capabilities you're granting

### 1. It reads and writes your messages

Once a channel is connected, the gateway can read messages sent to it and send
messages as you (or as your bot). Practically: **anyone who can message that
bot can put text in front of your agent.**

### 2. It can execute shell commands

This is the capability that separates OpenClaw from a chat window, and the one
that deserves your attention. It is **governed by exec policy** — the presets
are `deny-all`, `cautious`, and `yolo` — but the capability exists from day
one, so the setting is doing real work from day one.

> A tool-using agent that reads untrusted content and can run commands is, by
> construction, one convincing paragraph away from running the wrong one.
> That's not a flaw in OpenClaw; it's the shape of the whole category. It's why
> [`03-security.md`](03-security.md) exists.

### 3. It holds your API keys

Model provider keys live in its config so it can call models on your behalf.
Those keys are spendable money and, for some providers, access to your account.

### 4. It's reachable from your phone

Device pairing (`openclaw devices list` / `approve`) lets you talk to your
machine from a phone or another browser. That convenience is also a
remote-access path. It should be authenticated, revocable, and never a bare
open port. Channel pairing (`openclaw pairing list` / `approve`) is a
different surface: who may DM the bot.

---

## The trust decisions, made explicit

Before installing, answer these. Writing them down beats discovering your
answer later.

1. **Which machine?** A laptop with your SSH keys, cloud credentials, and
   client work is a very different host from a spare box. If it's the former,
   sandbox from the start.
2. **Which channels, and who can reach them?** A private DM channel with
   pairing required is a different exposure from a public group.
3. **May it run commands?** If you don't have a specific reason to say yes
   today, start at `deny-all` and add capability when you have a real use case.
4. **Local models, cloud models, or both?** Cloud means your prompts leave the
   machine. Local means they don't, and costs nothing per token, at the price
   of speed and capability.
5. **What is your rollback?** If it writes something wrong, how do you undo it?
   Version control on anything it can edit is the cheapest possible answer.

---

## What good looks like on day one

A setup you can defend, that still does something useful. **Policy before
onboard, onboard before a channel.**

```bash
npm install -g openclaw
openclaw exec-policy preset cautious   # ask before executing anything
openclaw exec-policy show              # read the words, not the exit code

openclaw onboard                       # you type every secret; bind loopback
openclaw gateway install
openclaw gateway status                # prove 127.0.0.1, typically :18789

openclaw security audit                # surface foot-guns immediately
openclaw secrets audit --check
openclaw sandbox explain               # confirm EFFECTIVE policy, not intent
```

Need **Node.js 24.16+** (upstream currently recommends Node 26). Node 20 is
too old for current OpenClaw.

Zero channels until pairing is understood, then **one** channel, one agent,
`cautious` or `deny-all`, no MCP servers yet. Live with that for a week; add
capability when you hit an actual limitation, not in anticipation of one.

Sandboxing is **opt-in** (`off` / `non-main` / `all`). If Docker or Podman is
missing, write that down — a command that runs can then reach the real
filesystem.

---

## What this is genuinely good at

Being fair about the upside, since the rest of this page is caution:

- **Asynchronous work.** Message it from anywhere; it works while you don't.
- **Chat as the interface.** History, notifications, files, groups — all
  already solved, on a device you already carry.
- **Durable context.** Sessions and memory mean it remembers last week.
- **Real actions.** Reading documents, running checks, producing artefacts —
  the gap between "AI that talks" and "AI that does".
- **Extensibility.** Skills and MCP servers, without writing a framework.

---

## What it is not

- **Not a toy.** It's infrastructure. It needs monitoring, backups, and updates.
- **Not free of running costs** unless you use local models exclusively.
- **Not set-and-forget.** See [`04-operating-it.md`](04-operating-it.md) — the
  interesting failures are all operational, and they're quiet.
- **Not a security product.** It gives you good controls; using them is yours.

---

## Uninstalling

Worth knowing before you start, not after:

```bash
openclaw uninstall     # removes gateway service + local data (CLI remains)
openclaw reset         # resets config/state, keeps the CLI
npm uninstall -g openclaw
```

Afterwards, **rotate any provider keys and bot tokens** it held. Removing the
software does not un-issue the credentials.
