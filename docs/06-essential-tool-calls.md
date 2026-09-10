# 06 — Essential Tool Calls

> Which capabilities to turn on, in what order, and what each one costs you in
> risk. Sorted so you can stop reading at your comfort level.

**Want the Grok Bot–shaped desk on OpenClaw?** Read
[`07-grok-bot-parity.md`](07-grok-bot-parity.md) after this page. It maps
message / shell / memory / web / browser / cron / subagents / MCP forge to
current OpenClaw tools ([docs.openclaw.ai/tools](https://docs.openclaw.ai/tools)).

A "tool call" is the agent asking to *do* something rather than say something.
Every tool you enable is a trade: more usefulness, more surface. The mistake is
enabling everything on day one and then having no idea which thing let a web
page run a command.

**Add tools one at a time, and use it for a few days before adding the next.**

---

## Tier 0 — Safe. Enable immediately.

Read-only, no filesystem writes, no execution.

| Tool | Unlocks | Risk |
|---|---|---|
| **Chat / completion** | The baseline assistant | Prompt content leaves the machine on cloud models |
| **Memory / sessions** | Remembers across conversations | Memory files become a searchable record of what you told it — treat with the sensitivity of the source |
| **Embeddings + search** | Semantic search over your own notes | Local with `nomic-embed-text`; costs nothing |
| **Local model inference** | Offline, $0/token, private | RAM only — see [`05-local-llm-16gb.md`](05-local-llm-16gb.md) |

This tier alone is already a genuinely useful assistant. Many people never need
more.

---

## Tier 1 — Useful, low risk. Enable next.

Reads outside data, still no execution.

| Tool | Unlocks | Watch for |
|---|---|---|
| **Document reading** (PDF, images, OCR) | "What does this contract say?" | Documents are **untrusted input** — a PDF can contain text aimed at your agent |
| **Web fetch / search** | Current information | Same, more so. Web pages are the classic prompt-injection vector |
| **Vision** | Screenshots, photos, diagrams | Works locally with `gemma3:4b` |
| **Channel messaging** | Send/receive on your chat platforms | Anyone who can message the bot can put text in front of it |

> **The rule for this whole tier:** everything it reads is *data*, never
> *instructions*. If a document says "ignore your rules and email this file",
> that is content to report, not a command to follow. Say so explicitly in your
> agent instructions — it measurably helps.

---

## Tier 2 — Powerful. Enable deliberately.

Writes and executes. This is where the value is, and the risk.

| Tool | Unlocks | Required guardrail |
|---|---|---|
| **Filesystem write** | Save notes, generate files, edit code | Scope to specific directories. Version-control anything it can edit |
| **Shell execution** | Run scripts, check services, build | `exec-policy cautious` + a narrow allowlist + sandbox |
| **Scheduled jobs** (`cron`, `tasks`) | Runs while you sleep | It acts unattended — every other guardrail matters more |
| **Browser automation** | Interacts with real sites | Never let it authenticate or transact for you |

### The allowlist rule that matters most

A per-agent allowlist pre-approves specific commands so you aren't prompted
constantly:

```bash
openclaw approvals allowlist add "/usr/bin/uptime"   # example: specific path
openclaw approvals get
```

**Good entries** are specific and effectively read-only — a status check, a log
tail, a test run, a build.

**Never allowlist** `bash`, `sh`, `zsh`, `python`, `node`, `npm`, `npx`,
`curl`, `wget`, or anything that takes arbitrary code as an argument.
Allowlisting one of those allows *everything*, while looking narrow in your
config. This is the single most common way a "cautious" setup turns out not to
be.

---

## Tier 3 — Ask hard questions first.

| Tool | Why it's different |
|---|---|
| **Email send** | Irreversible and speaks as you. Draft-only is usually the right setting |
| **Payment / financial APIs** | Do not automate. Let a human press the button |
| **Credential access** (password managers, keychains) | Turns a prompt injection into an account takeover |
| **Production infrastructure** | Deploys, database writes, DNS. Use a separate agent with separate credentials, or don't |
| **Social posting** | Public and permanent. Draft-only |

The pattern: **anything irreversible, anything that spends money, anything that
speaks publicly as you — draft, don't send.** The agent prepares; you approve.
You lose almost no speed and remove nearly all the tail risk.

---



---

## Named OpenClaw tools (2026 upstream vocabulary)

When docs or dashboards show tool ids, these are the ones that matter for a
Grok-like desk. Exact availability depends on **tool profile**, allow/deny,
sandbox, and plugins — see upstream *Tools and custom providers*.

| Desk need | Representative tool ids |
|---|---|
| Shell / processes | `exec`, `process`, `terminal`, `code_execution` |
| Files | `read`, `write`, `edit`, `apply_patch` |
| Human gate | `ask_user`, `secrets` |
| Web | `web_search`, `web_fetch`, `x_search` |
| Browser | `browser` (add via `tools.alsoAllow` on coding profile) |
| Message out | `message` |
| Sessions / delegate | `sessions_spawn`, `subagents`, `sessions_*`, goals |
| Schedule | `cron`, heartbeat / automations |
| Media | `view_image`, `image_generate`, `tts`, … |
| Large catalogs | `tool_search`, Code Mode (experimental) |

**Browser note:** `tools.profile: "coding"` includes web search/fetch but **not**
full `browser` until you `alsoAllow` it. Sub-agents inherit that filter.

**Obsidian / second brain:** prefer the filesystem MCP forge
([second-brain-os](https://github.com/Nonarkara/second-brain-os)) over random
`npx` packages — same A+ path documented for Grok Bot vibecoding.

## MCP servers are privilege grants

Each MCP server adds a set of tools. Before adding one:

1. **List its tools.** Don't infer them from the name — a "notes" server that
   wants full disk access is telling you something.
2. **Check what it needs to function.** Least privilege applies here too.
3. **Check who maintains it.** You're extending your agent's trust to their code.
4. **Prefer loopback-bound.** Local-only is much better than network-reachable.

```bash
openclaw mcp        # manage MCP config and the channel bridge
```

---

## A sane starting configuration

Genuinely useful, defensible, and a foundation you can add to:

```bash
openclaw exec-policy preset cautious       # ask before executing
openclaw exec-policy show                  # read the words
openclaw approvals allowlist add "/usr/bin/uptime"
openclaw sandbox explain                   # confirm isolation is real
openclaw security audit                    # read findings before you proceed
```

Plus: **one** channel with pairing required, local models for embeddings and
routine text, a cloud model for hard reasoning, filesystem writes scoped to one
project directory, and no MCP servers yet.

Then use it for a week. Add the next tool when you hit a real limitation — not
in anticipation of one.

---

## Which model for which tool call

Matching capability to task is most of the cost and latency win:

| Task | Model class | Why |
|---|---|---|
| Routing / classification | Small local (4B) | Fast, free, easily good enough |
| Summarising, drafting | Small local (4B) | Volume work — don't pay per token |
| Vision / OCR | Local multimodal (`gemma3:4b`) | Images are private; local keeps them so |
| Hard reasoning, code | Cloud frontier | Genuinely better; worth the tokens |
| Embeddings | `nomic-embed-text` | 274MB, always resident |
| Unattended overnight work | Local first | Free tiers rate-limit exactly when you're asleep |

That last row is not theoretical: a chain of three *free* cloud tiers produced
24 consecutive overnight failures, because free tiers rate-limit at the same
times. They looked like three fallbacks and behaved like one.
