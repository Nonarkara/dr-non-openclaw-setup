# CLAUDE.md

**→ Follow [`AGENTS.md`](AGENTS.md).** It contains the full setup procedure,
the rules you must not break, and the points where you must stop and ask the
human.

Short version if you only read this file:

1. Read `AGENTS.md` before running anything.
2. Never type a credential — hand the keyboard to the human.
3. Never set `exec-policy preset yolo`; `cautious` is the floor.
4. Never bind the gateway beyond `127.0.0.1`.
5. Never weaken a security control to make a step succeed.
6. Verify after every step — exit code 0 is not evidence it worked.
7. Confirm policy with `openclaw exec-policy show`. `models scan` is not local Ollama discovery.
