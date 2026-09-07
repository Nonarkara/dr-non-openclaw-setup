# Diagrams

Three maps of the same system. Prefer these over the older posters in this folder.

| File | What it answers |
|---|---|
| [Message path](#a-message--gates--action) | How a chat message becomes an action — and where you can still say no |
| [Security layers](#b-security-layers) | Pairing, loopback, exec policy, sandbox, SecretRefs — in that order |
| [First week](#c-first-week-order) | What to do in the first hour, then the rest of the week |

Mermaid sources (for rendering or editing): [`message-path.mmd`](message-path.mmd), [`security-layers.mmd`](security-layers.mmd), [`first-week.mmd`](first-week.mmd).

PNG renders of the same three maps sit beside the sources when present (`message-path.png`, `security-layers.png`, `first-week.png`). If a PNG and the mermaid disagree, **the mermaid is the contract**.

The older studio posters [`banner.png`](banner.png) and [`banner-cyberpunk.png`](banner-cyberpunk.png) are illustrations, not setup instructions. They are not a live UI. Do not treat slogans on those posters as policy.

---

## A. Message → gates → action

A stranger's paragraph is **data**. It is not permission. The model *asks* to run a command; exec policy decides.

```mermaid
flowchart TB
  subgraph inbound["1. Inbound"]
    YOU["You send a message"]
    CH["Chat channel<br/>Telegram / Discord / …"]
    YOU --> CH
  end

  subgraph identity["2. Who is this?"]
    PAIR{"Sender paired<br/>and approved?"}
    DROP["Stopped here<br/>pairing code only"]
  end

  subgraph brain["3. Gateway on this machine"]
    GW["Gateway<br/>bound to 127.0.0.1"]
    AG["Agent + session memory"]
    MODEL["Model<br/>asks for a tool"]
    GW --> AG --> MODEL
  end

  subgraph policy["4. May it act?"]
    POL{"Exec policy"}
    DENY["deny-all<br/>refused"]
    ASK["cautious<br/>you approve this command"]
    YOLO["yolo<br/>no ask — do not use"]
  end

  subgraph run["5. If allowed"]
    SBX["Sandbox if enabled<br/>Docker / Podman"]
    TOOL["Tool / skill / MCP"]
    REPLY["Reply back on the channel"]
  end

  CH --> PAIR
  PAIR -->|no| DROP
  PAIR -->|yes| GW
  MODEL --> POL
  POL -->|deny-all| DENY
  POL -->|cautious| ASK
  ASK -->|you say no| DENY
  ASK -->|you say yes| SBX
  POL -->|yolo — never the default| SBX
  SBX --> TOOL --> REPLY
```

Two pairing surfaces, not one:

- **Channel pairing** (`openclaw pairing list` / `approve`) — who may DM the bot
- **Device pairing** (`openclaw devices list` / `approve`) — which phone or browser may talk to the gateway

<p align="center"><img src="message-path.png" alt="Rendered flowchart: a chat message hits pairing, then a loopback gateway, then exec policy, then an optional sandbox, then a reply." width="90%"></p>

Prose: [`docs/02-architecture.md`](../docs/02-architecture.md).

---

## B. Security layers

Each layer fails closed. Skipping one to “make a step work” is how quiet incidents start.

```mermaid
flowchart TB
  subgraph L1["Layer 1 — Who may talk"]
    P["openclaw pairing list / approve<br/>Inbound DMs need a pairing code"]
    D["openclaw devices list / approve<br/>Phones and browsers are devices, not ports"]
  end

  subgraph L2["Layer 2 — Where it listens"]
    B["gateway.bind = loopback<br/>127.0.0.1 only"]
    R["Remote reach = pairing or an authenticated tunnel<br/>Never 0.0.0.0, never a bare public port"]
  end

  subgraph L3["Layer 3 — Whether a command may run"]
    E["openclaw exec-policy preset cautious<br/>or deny-all"]
    S["openclaw exec-policy show<br/>Read the effective preset — do not trust the exit code"]
  end

  subgraph L4["Layer 4 — What a command can reach"]
    X["openclaw sandbox explain<br/>Effective mode: off / non-main / all"]
    W["No Docker? Say so. The host filesystem is then in play."]
  end

  subgraph L5["Layer 5 — What it may hold"]
    K["SecretRefs / secrets store<br/>Keys are references, not files in git"]
    A["openclaw security audit<br/>openclaw secrets audit --check"]
  end

  L1 --> L2 --> L3 --> L4 --> L5
```

`yolo` is a named preset upstream. This guide never recommends it as a default. Its habitat is a disposable container you would delete without blinking.

<p align="center"><img src="security-layers.png" alt="Rendered stack of five security layers: pairing, loopback bind, exec policy, sandbox, SecretRefs." width="70%"></p>

Prose: [`docs/03-security.md`](../docs/03-security.md).

---

## C. First-week order

Policy is set **before** anything inbound exists. That is the whole method.

```mermaid
flowchart TB
  subgraph hour0["Hour 0 — still offline"]
    direction TB
    A["1. Survey the machine<br/>Node 24.16+ · disk · Docker · Ollama"]
    B["2. Install the CLI"]
    C["3. Set exec policy<br/>cautious or deny-all"]
    D["4. Confirm with exec-policy show"]
    A --> B --> C --> D
  end

  subgraph hour1["Hour 1 — local only"]
    direction TB
    E["5. Onboard — you type every secret"]
    F["6. Install the gateway service<br/>confirm 127.0.0.1:18789"]
    G["7. security audit + sandbox explain"]
    E --> F --> G
  end

  subgraph day2["Day 2 — optional local models"]
    direction TB
    H["8. Pull small Ollama models"]
    I["9. Prove a real reply<br/>then models list --provider ollama"]
    H --> I
  end

  subgraph day3["Day 3 — one inbound path"]
    direction TB
    J["10. Connect exactly one channel"]
    K["11. pairing list / approve<br/>devices list"]
    L["12. Your message gets a reply<br/>a stranger's does not"]
    J --> K --> L
  end

  subgraph week["The rest of the week"]
    direction TB
    M["13. Live with one agent,<br/>one channel, cautious"]
    N["14. Add a tool only when<br/>you hit a real limit"]
    M --> N
  end

  D --> E
  G --> H
  I --> J
  L --> M
```

<p align="center"><img src="first-week.png" alt="Rendered flowchart of the first-week setup order: survey and lock policy while offline, onboard and audit on loopback, optional local models, then one paired channel." width="80%"></p>

Humans: the numbered first-hour in the [README](../README.md#first-hour-for-humans). Agents: [`AGENTS.md`](../AGENTS.md).
