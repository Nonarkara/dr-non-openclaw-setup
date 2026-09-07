# 03 — Security

> The most important page here. Everything else is upside; this is downside.

OpenClaw's value comes from being connected to your messages, your models, and
your machine at the same time. That is also the entire risk. This page is about
keeping the first without inheriting the second.

---

## Threat model: what are we actually defending against?

Be specific. Vague fear produces vague configuration.

| # | Threat | Realistic? | Mitigated by |
|---|---|---|---|
| 1 | **Prompt injection → shell** — a webpage, PDF, or message contains text that persuades the agent to run a command | **Very.** This is the headline risk of any tool-using agent | Exec policy + allowlist + sandbox |
| 2 | **Untrusted inbound sender** — a stranger DMs your bot and gets it to act | Yes, if channels are open | Pairing / approval for inbound DMs |
| 3 | **Credential exposure** — provider keys readable in config, logs, or a repo | Yes — the most common real-world incident | SecretRefs, `security audit`, `.gitignore` |
| 4 | **Gateway exposed to the network** — the control plane reachable beyond localhost | Yes, if you bind it wide or tunnel it | Bind loopback; device pairing for remote |
| 5 | **Over-broad MCP tools** — an added MCP server quietly grants filesystem or network reach | Yes, and easy to miss | Audit each server's tools before adding |
| 6 | **Runaway cost** — a loop burns provider credits | Yes | Rate limits, budget caps, local models |

The one to internalise is **#1**. Your agent reads untrusted content — that's
its job. Treat every byte it reads from the outside as *data*, never as
instructions, and never let "the model decided to" be the only thing standing
between a web page and your shell.

Layers, drawn: [`diagrams/README.md`](../diagrams/README.md#b-security-layers).
Set them in the first-week order: [`diagrams/README.md`](../diagrams/README.md#c-first-week-order).

---

## The single most consequential setting: exec policy

```bash
openclaw exec-policy preset cautious
openclaw exec-policy show
```

Three presets (the third is named so you can recognise it — not so you set it):

| Preset | Behaviour | Use when |
|---|---|---|
| `deny-all` | No shell execution at all | Conversational assistant; safest default |
| `cautious` | Ask for approval before executing | **Start here.** Sane default for real work |
| `yolo` | Execute without asking | Never on a machine with anything of value |

`yolo` is not "advanced mode", it's "no mode". Its correct habitat is a
disposable container you'd be happy to delete, not your laptop.

**Never raise the policy to debug something.** If a command is failing, that is
a reason to look at the command — not to remove the thing that would have asked
you first. Almost every over-permissioned system got that way one debugging
session at a time.

### Per-agent allowlists

Blanket approval is blunt. An allowlist lets a specific agent run a specific,
enumerated set of commands without prompting every time:

```bash
openclaw approvals allowlist add "/usr/bin/uptime"   # specific path, not a shell
openclaw approvals get                               # what is actually approved
```

Good allowlist entries are **specific and read-only-ish**: a status check, a
log tail, a build. Bad ones are interpreters and package managers — `bash`,
`sh`, `python`, `node`, `npm`, `curl | sh` — because allowing one of those
allows everything, and does it under a name that looks narrow.

---

## Sandboxing: contain what you can't prevent

Policy asks *whether* a command runs. Sandboxing decides *what it can reach if
it does.* You want both.

```bash
openclaw sandbox list        # containers and status
openclaw sandbox explain     # the effective policy for a session/agent
openclaw sandbox recreate --all   # rebuild after config changes; next use reseeds
```

Sandboxing is **opt-in**. `agents.defaults.sandbox.mode` is `off` (host),
`non-main` (only non-main sessions), or `all`. A common surprise: in
`non-main`, a group or channel session is **not** "main", so it is sandboxed
when you thought it wasn't — or the reverse.

`sandbox explain` deserves a habit. Effective policy is the product of several
layers, and the surprising part is not what you configured — it's what those
layers combine into. Check the *effective* policy, not your intent. Config
edits do not rewrite a running container; recreate, then prove the new
`explain` output.

Run agents that touch untrusted content — anything reading the web, email, or
messages from strangers — **inside a sandbox**, and give them the narrowest
filesystem mount that still does the job.

---

## Secrets

```bash
openclaw security audit           # run this today, and after every config change
openclaw security audit --deep    # adds a live Gateway probe; optional
openclaw secrets audit --check    # plaintext, unresolved refs, precedence drift
openclaw secrets configure        # interactive SecretRef planner (you type)
```

`--fix` on `security audit` applies a small, documented set of safe
remediations (file permissions, some open group policies). It will not rotate
keys, disable tools, or change bind/auth. Do not treat a clean exit as a
clean system — read the findings.

Rules that prevent the incidents that actually happen:

1. **Never paste a raw key into config that lands in a repo.** Use SecretRefs
   so config references a secret rather than containing it.
2. **Assume logs leak.** Verbose logging plus an error path that dumps the
   request is the classic way a key reaches a file you later share.
3. **Keys in shell commands are keys in your shell history** — and in your
   agent's transcript. Prefer config or env files over inline flags.
4. **Rotate on suspicion, not proof.** Rotation is cheap; investigation is not.
5. **Scan before you publish.** Before pushing any config-adjacent repo:

```bash
grep -rInE "sk-[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|[0-9]{9,10}:AA[A-Za-z0-9_-]{30,}" .
```

---

## Channel exposure: every channel is an inbound path

Adding a chat channel means a message from outside can now reach a process on
your machine. That is fine — it's the point — provided you control *who*.

- **Require pairing/approval for inbound DMs.** Default `dmPolicy` is
  `"pairing"`: unknown senders get a code, not an action. Inspect and approve
  with `openclaw pairing list <channel>` and `openclaw pairing approve …`.
  Without that, anyone who finds your bot is talking to your gateway.
- **Groups are a different trust level than DMs.** Anyone in a group can
  address the bot. Assume group content is untrusted, always.
- **Bot tokens are credentials.** A leaked token lets someone impersonate your
  bot and read its messages. Treat as a password; rotate on exposure.
- **Prefer one narrow agent per channel** over one powerful agent on all of
  them. Blast radius is a design choice.

---

## The gateway itself

- **Bind to loopback** unless you have a specific reason not to. The control
  plane is not something to expose to a LAN, let alone the internet.
- **For phone or extra-browser access, use device pairing**
  (`openclaw devices list`, `openclaw devices approve <requestId>`) rather
  than opening a port. Pairing gives revocable per-device tokens. Approving
  without an id only *previews* the newest request.
- **If you must reach it remotely, tunnel it** with something that
  authenticates (Tailscale, an authenticated reverse proxy) — never a bare
  public port.
- **Revoke devices you no longer use.** Tokens outlive the phones they were
  issued to.

---

## MCP servers: audit before you add

Each MCP server adds tools your agent can call. Some grant broad filesystem or
network reach in one line of config.

Before adding one, ask:

1. **What tools does it expose?** List them — don't assume from the name.
2. **What does it need to work?** A vault-notes server needing full disk access
   is a red flag.
3. **Who maintains it?** You are granting it your agent's trust.
4. **Is it reachable only locally?** Loopback-bound is much better than not.

The general principle: **an MCP server is a privilege grant, not a plugin.**

---

## Hardening checklist

Work down this list once; re-run the audits after any config change.

- [ ] `openclaw exec-policy show` prints `cautious` or `deny-all`
- [ ] `openclaw gateway status` shows a **loopback** listener (typically `127.0.0.1:18789`)
- [ ] `openclaw security audit` — findings read, not just exit 0
- [ ] `openclaw secrets audit --check` — no unexpected plaintext
- [ ] `openclaw sandbox explain` — effective mode matches what you *think*
- [ ] Sandboxing enabled (`non-main` or `all`) for any agent touching untrusted content
- [ ] Inbound DM pairing required; `pairing list <channel>` reviewed
- [ ] Device pairing reviewed (`devices list`); unused devices removed
- [ ] Gateway bound to loopback; remote access via pairing or authenticated tunnel
- [ ] Allowlist contains no shells, interpreters, or package managers
- [ ] Provider keys via SecretRef / secrets store, not inline in config
- [ ] Config and state directories excluded from any repo you publish
- [ ] Secret scan passes before every push
- [ ] Unused channels removed
- [ ] Each added MCP server's tool list reviewed
- [ ] Backups exist and have been **restored once** to prove they work

---

## If something goes wrong

```bash
openclaw doctor              # diagnose + repair config/gateway/channel issues
openclaw status              # gateway, channels, models, recent sessions
openclaw logs                # tail gateway logs
openclaw sessions            # what conversations exist
```

**On suspected compromise, in this order:** stop the gateway → rotate every
provider key and bot token → revoke paired devices → read `openclaw sessions`
and the logs to establish what was actually reached → only then restart.

Rotate first, investigate second. The keys are the thing that keeps costing you
after the incident ends.
