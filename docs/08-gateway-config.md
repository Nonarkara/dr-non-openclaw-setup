# 08 — Gateway config

> Where the settings live, which defaults this repo pins, and how to prove the
> process is healthy. The example file is a map. The CLI is what writes your
> real config.

Checked against **OpenClaw 2026.9.6**. Schemas drift. `openclaw <cmd> --help` and [docs.openclaw.ai](https://docs.openclaw.ai/) win when they disagree.

---

## Where config lives

| Path | What it is | In git? |
|---|---|---|
| `~/.openclaw/openclaw.json` | Gateway, tools, models, channels | Never |
| `~/.openclaw/.env` | Env values the service can actually read | Never |
| `~/.openclaw/workspace` | Agent workspace | Never |
| [`config/openclaw.example.json5`](../config/openclaw.example.json5) | Documented shape, no secrets | Yes |
| [`config/env.1password.example`](../config/env.1password.example) | `op://` references only | Yes |

`./bin/bootstrap` does not copy the example over a live file. It sets `gateway.mode`, `gateway.bind`, exec policy, and (when you already have a token) the token SecretRef through `openclaw config set`, which validates as it writes.

Inspect without dumping secrets:

```bash
openclaw config file
openclaw config validate
openclaw config get gateway.bind
openclaw config get gateway.mode
openclaw config get gateway.auth.mode
```

`openclaw config get gateway.auth.token --json` redacts the value. Prefer that over opening the file in a screenshot.

---

## Defaults this path pins

| Key | Value | Why |
|---|---|---|
| `gateway.mode` | `local` | The process refuses to start a local gateway without it |
| `gateway.bind` | `loopback` | Control plane stays on `127.0.0.1`. Runtime default is also loopback; the file pins it so a later edit is visible |
| `gateway.port` | `18789` | Upstream default. Doctor and `gateway status` print the effective port |
| `gateway.tailscale.mode` | `off` in the example | Remote access is device pairing, not Funnel |
| `gateway.auth.mode` | `token` | Auth stays on even for loopback, so other local processes must present the token |
| `gateway.auth.token` | env SecretRef `OPENCLAW_GATEWAY_TOKEN` | The json holds `{ source, provider, id }`, not the token |
| exec policy | `cautious` or `deny-all` | Upstream's untouched default is `security=full`, `ask=off`. That is not a safe baseline |

`cautious` means host `gateway`, security `allowlist`, ask `on-miss`, ask fallback `deny`. `deny-all` means security `deny`. `yolo` means security `full` and ask fallback `full`. This repo's scripts will not apply `yolo`.

A phone reaches the gateway by device pairing (`openclaw devices list` / `approve <requestId>`), not by changing `bind` to `lan`.

---

## Providers and models

Onboard is the supported way to attach a provider. You type the key. Bootstrap will not read a key out of your clipboard or your shell and paste it into a file for you.

| You have | What to run | Notes |
|---|---|---|
| Anthropic, OpenAI, OpenRouter, Gemini, Groq, xAI, others | `openclaw onboard --classic` | The full `--auth-choice` list is in `openclaw onboard --help`. It is long and it changes. |
| Ollama on this machine | `./bin/bootstrap --policy cautious --onboard-local` | Needs `http://127.0.0.1:11434` and a pulled model. Native base URL, **no `/v1`**. `/v1` breaks tool calling. |
| Nothing yet | stop at the baseline | A gateway with no model credential is a process, not an assistant. Doctor warns. |

Local model ids that fit a 16 GB Mac are in [`05-local-llm-16gb.md`](05-local-llm-16gb.md): `nomic-embed-text`, `qwen3:4b`, `gemma3:4b`, and `gemma4:12b` only when it is the heavy process. Pin a default with an id `openclaw models list` printed:

```bash
openclaw models list --provider ollama
openclaw models set ollama/qwen3:4b
```

`openclaw models scan` is OpenRouter's free catalog, not Ollama.

The example config lists `qwen3:4b` under `models.providers.ollama` so the shape is visible. A non-empty manual list skips discovery. Delete that block if you are not running Ollama, and do not list a model you have not pulled.

Reasoning models can return an empty string with a success status unless thinking is off (`params.thinking: false`, and `"think": false` on a raw Ollama chat call).

---

## Tools, in the order that stays defensible

Full risk table: [`06-essential-tool-calls.md`](06-essential-tool-calls.md). Grok-shaped desk jobs, without pretending the products are the same: [`07-grok-bot-parity.md`](07-grok-bot-parity.md).

Upstream's local onboard sets `tools.profile` to `coding` when you have not set one. That profile includes files, runtime, web search/fetch, sessions, memory, and cron. It does **not** include `browser` until you add it:

```json5
{
  tools: {
    profile: "coding",
    alsoAllow: ["browser"],
  },
}
```

Add `browser` when you have a reason, not on day one. Sub-agents do not get `cron` or outbound `message`; the parent coordinates. That is upstream behavior, and it is the one you want.

Shell is not "on" just because the coding profile includes `exec`. Exec policy is the gate:

```bash
openclaw exec-policy show
openclaw approvals get
```

Allowlist a specific binary if you are tired of approving it. Do not allowlist `bash`, `sh`, `node`, `npm`, `curl`, or `wget`.

MCP servers are separate privilege grants:

```bash
openclaw mcp list
openclaw mcp probe <name>
openclaw mcp tools <name>
```

Add one, list its tools, live with it. The Obsidian memory forge, when you want it, is the filesystem bridge documented in [`07-grok-bot-parity.md`](07-grok-bot-parity.md) — not a random `npx` package, and not on day one.

---

## Channels

Zero until doctor is boring. Then one.

```bash
openclaw channels status
openclaw channels add          # interactive; you type the bot token
openclaw pairing list <channel>
openclaw devices list
```

Default DM policy is pairing: an unknown sender gets a code, not a tool call. Do not set an open DM policy to "test".

---

## Healthy, in one screen

```bash
./bin/doctor
openclaw gateway status          # bind host and probe, not the supervisor adjective
openclaw health                  # only meaningful once something is listening
openclaw security audit          # read warnings; 0 critical
openclaw secrets audit --check   # plaintext and unresolved refs
openclaw exec-policy show
```

`gateway status --json` fields this repo trusts:

| Field | Pass |
|---|---|
| `gateway.bindMode` | `loopback` |
| `gateway.bindHost` | `127.0.0.1` |
| `port.status` | `busy` once you expect it up; `free` means nothing is listening |
| `config.cli.exists` | true |

A loopback bind with `gateway.trustedProxies` empty produces an audit **warning** about reverse-proxy headers. That warning is correct while the Control UI stays on this machine. Do not add a trusted proxy, and do not open the port, to turn the warning off.

After a config change that touches bind or port, restart and prove a new status line, not just a zero exit:

```bash
openclaw gateway restart
openclaw gateway status
```
