# 04 — Operating It

> Installing is an afternoon. Keeping it alive unattended is the actual skill.
> Everything here is from running this stack overnight, on one laptop, for a
> summer — and every failure below was silent.

---

## The pattern behind almost every incident

**Something reported success while doing nothing useful.**

Health checks passing on dead services. Restarts that restarted nothing. Model
calls returning empty strings with exit code 0. Imports that skipped everything.
Truncation with no warning.

If you internalise one habit, make it this: **verify the effect, not the exit
code.** After a restart, check the PID changed. After an import, count the rows.
After a fix, reproduce the original failure and watch it fail to happen.

---

## Health checks that actually detect failure

The first monitor logged `OK: model server alive` every five minutes straight
through a total outage — because it probed a version endpoint that answers in
milliseconds whether or not inference works.

> **A probe must exercise the same code path that fails.** If inference breaks,
> the probe must run inference.

Then the corrected probe caused the next outage. Real inference **loads the
model** — several GB — and runtimes pin it for a keep-alive window. A probe on
a 5-minute schedule keeps a multi-GB model resident permanently, which on a
16GB machine starved the very service the monitor existed to protect.

> **A health check is not free.** If it reserves a resource, it is part of the
> system it measures. Release immediately (`keep_alive: 0` or equivalent), and
> don't force a cold load just to take a temperature — an idle service with
> nothing loaded is a normal state, not a fault.

---

## Restart logic that actually restarts

Two bugs that together produced **198 restarts in one day, none of which did
anything:**

1. **Relaunching an app that's already running is a no-op.** The kill list only
   contained the *child* process. The child died, the parent survived, nothing
   respawned. Kill the **parent** too, or your restart is theatre.

2. **Don't throttle on process age.** If a service fails to spawn at all there
   is no process, so there is no age, so the throttle is skipped and it retries
   every cycle forever. **Throttle on last-restart time**, recorded in state:

```python
last = state.get("last_restart", {}).get(name)
if last and (now - last) < GRACE:
    return                      # inside the grace window; leave it alone
state.setdefault("last_restart", {})[name] = now
```

Also give a starting service time to start. Something loading a multi-GB model
under memory pressure can take minutes; kill it at 30s and you've built a
machine that guarantees it never comes up.

---

## Alert fatigue is a system failure

Thirty identical "SERVICE DOWN" messages in one day for one known fault is how
a person learns to swipe your alerts away — and then misses the one that
mattered.

Back off exponentially while a fault **persists**; reset on recovery:

```
30m → 1h → 2h → 4h → 6h (cap)
```

Across 24h of continuous downtime that's **7 alerts instead of 30**, while a
genuinely new incident still pages immediately.

---

## Failure modes that will cost you a day

| Symptom | Actual cause |
|---|---|
| Local model dies instantly, `Remote end closed connection` | **Disk full.** Swap lives on the boot volume; the KV-cache allocation had nowhere to grow. Check `df -h /` *before* touching model parameters |
| Bot dormant, gateway "healthy" | A live dependency behind **removable media**. It never presents as "drive gone" — it presents as an unrelated service hanging |
| Model call succeeds, returns empty string | A **reasoning model** spent its token budget on hidden thinking. Disable thinking for generation tasks |
| Confident but thin answers | **Context window silently truncated** the input. Set it explicitly; shrink the prompt yourself rather than letting the server cut wherever it likes |
| Config fixed, still broken | A long-lived process still holds the **old config in memory**. Not fixed until every process that read it restarted |
| Provider returns 400 for weeks | **Model name retired.** Verify against `GET /v1/models`; never trust a hard-coded name |
| Vision/tool call rejected as invalid type | **Endpoint capability mismatch** — e.g. a *coding* endpoint that only accepts text. List the models; don't assume the family has the capability |
| Restart "worked", nothing changed | `pkill -f "a\|b"` — macOS `pkill` has no BRE alternation, so it silently matches **nothing** |

---

## Make long jobs resumable and retries become free

The highest-leverage reliability change available.

A long chain — ingest → generate → render — throws away everything if any link
breaks. Two guards fix it:

- **Already-done check:** if the final artefact exists, exit immediately.
- **Resume check:** if the expensive intermediate exists, skip straight past
  the expensive stages.

With both, a retry ladder is safe and nearly free:

```
21:00  full attempt
23:30  retry — resumes from whatever succeeded
02:00  retry
04:30  last chance before it's needed
```

Each rung only redoes what actually failed, so a transient rate-limit at 21:00
stops being a missed morning.

**Add a lock.** Two concurrent runs of a memory-hungry job on one machine is
the same resource exhaustion that breaks everything else here. `mkdir` is
atomic and makes a fine lock — with a stale-lock check for runs killed before
cleanup. And don't `exec` inside the wrapper: it replaces the shell, so your
`EXIT` trap never fires and the lock leaks forever.

---

## A monitoring setup that earns its keep

```bash
openclaw gateway status   # listener, bind, last error — prove loopback
openclaw status           # gateway, channels, models, sessions
openclaw health           # detailed gateway health
openclaw doctor           # diagnose + repair
openclaw logs             # tail
```

`openclaw gateway status` is the line that tells you whether the process is
actually listening, and on which address. Trust `Listening:` and
`Probe target:` more than a supervisor that says "running".

Wrap them in a watchdog that checks, in this order — each rules out everything
above it:

1. **Disk free.** The cause of more "unrelated" failures than anything else.
2. **Gateway reachable** — and reachable via a call that does real work.
3. **Dependencies** (model runtime, any local services) — real probes, released
   immediately.
4. **Recent activity** — a gateway that's up but hasn't processed anything in
   24h is a different, quieter failure.

Then: alert with backoff, restart with a real kill and a time-based throttle,
and **never restart a service out from under a long-running job.**

---

## Backups

- Back up config and state; **restore once to prove it works.** An untested
  backup is a hypothesis.
- Keep recent backups on the **same disk** as the thing they protect, so they
  survive a cable falling out; archive older ones elsewhere. Backups behind
  removable media stop existing exactly when you need them.
- Watch retention arithmetic: `N snapshots × a database that grew 10×` is how a
  disk fills. Retention set once against a small database is a time bomb.
- **Rotate keys after any exposure**, including after uninstalling.

---

## The short version

- Verify the effect, not the exit code
- A probe must exercise the failing path — and must not reserve what it measures
- Kill the parent, throttle on time, and let a starting service start
- Alerts that repeat are alerts that get ignored
- Check the disk before you debug the model
- Never put a live dependency behind removable media
- Make expensive steps resumable; then retrying costs nothing
