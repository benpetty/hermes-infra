# Privacy considerations

The longer-form companion to the privacy section in the README. If you're skimming, the README covers the operational points; this document explains *why* and walks through threat scenarios in more depth.

## The framing

Every message you send Hermes touches **four distinct trust boundaries**:

```
Your phone (Telegram client)
     │
     ▼
Telegram servers ────────────────────── (1) Telegram has the cleartext
     │
     ▼
Telegram Bot API webhook / long-poll
     │
     ▼
Hermes gateway on your Hetzner VPS ──── (2) Hetzner could in theory access
     │
     ▼
OpenRouter API ──────────────────────── (3) OpenRouter sees prompt + reply
     │
     ▼
Anthropic / OpenAI / DeepSeek / etc. ── (4) Model provider sees prompt
```

Each boundary has its own data retention policy, jurisdiction, breach history, and threat model. "Sharing with Hermes" is not the same as writing in a private journal — it's writing in a multi-tenant pipeline.

There's a useful frame from operational security: data is safest at the point where it's never written down. The next-safest is at the point where one party holds it. The least safe is at the point where multiple commercial entities, each with their own retention policies, all hold copies. Hermes is the third case.

## Who actually sees what

### Telegram

- **Sees**: every message body + metadata (you ↔ bot, timestamps, frequency)
- **Storage**: indefinitely on their servers. Bot chats are **not** end-to-end encrypted — only Secret Chats are, and bots can't use Secret Chats by design.
- **Jurisdiction**: Telegram FZ-LLC (Dubai), historically resistant to government data requests but compliance has shifted post-Durov arrest in 2024. They now share some metadata under specific legal frameworks.
- **Realistic threat**: Telegram account compromise (your phone gets pwned), subpoena to Telegram, or a future internal breach.
- **Bottom line**: Telegram bot chats are not private in the way you might want. Treat them as if Telegram (and any of its insiders) could read them.

### Hetzner (your VPS)

- **Sees**: cleartext messages on disk, SQLite of every conversation, your memory file, all API keys in `~/.hermes/.env`.
- **Storage**: until you `make destroy` (or they image-snapshot the VM for legal/abuse reasons).
- **Jurisdiction**: German GDPR-bound, generally privacy-friendly, but with hypervisor-level access in theory and subpoena-respondable under German law.
- **Realistic threat**: your Hetzner account is taken over (password / MFA bypass), an attacker gets root on the VM, reads everything.
- **Bottom line**: trust Hetzner about as much as you trust any cloud provider — meaning probably fine for personal use, not bulletproof against state-actor-level adversaries.

### OpenRouter

- **Sees**: full prompt + response text on every API call.
- **Storage**: 30 days by default for billing/abuse purposes. **You can disable logging** in their dashboard (Settings → Inference Privacy).
- **Realistic threat**: their breach exposes 30 days of your conversations. They're a relatively young company; the surface is plausible.
- **Bottom line**: a single chokepoint for everything. Worth disabling logging if you care.

### Model provider (Anthropic, OpenAI, DeepSeek, etc.)

OpenRouter routes your queries to whichever model provider you've configured (e.g., `anthropic/claude-sonnet-4`). That provider's terms apply to the actual prompt content.

- **Anthropic / OpenAI (paid API)**: no training on API inputs by default. 30-day retention for safety review. Subject to subpoena.
- **DeepSeek** and other Chinese providers: privacy is less clear. May retain inputs and use for training. Subject to PRC data localization laws — data may be accessible to Chinese government under certain conditions.
- **Other providers via OpenRouter**: varies widely; some are sketchy. Read the specific provider's privacy policy before sending anything sensitive through them.
- **Bottom line**: pin to known-good providers (Anthropic, OpenAI) for sensitive context. Be deliberate about routing.

### Hermes itself (on your VPS)

- **Stores**: SQLite db of all sessions, memory file with "facts about you," autonomously-generated skill files, conversation history.
- **All on your VPS**, so this is "you-to-you" risk — assuming the VPS isn't compromised.
- **The agent autonomously creates skills and memories** that contain personal facts. Those are files on the VPS that get re-read on every conversation.
- **Bottom line**: Hermes is building a structured profile of you over time. Audit it.

## Threat scenarios worth thinking about

**Telegram account compromise**: an attacker gets your Telegram credentials. They can read your bot chat history. They can also try to send commands to your bot, but `TELEGRAM_ALLOWED_USERS` blocks them unless they spoof your user ID (hard). Mitigation: strong Telegram password + 2FA.

**Hetzner account takeover**: attacker breaks into your Hetzner account, gets root on the VM (or just takes a snapshot of the disk). Reads `.env` (= API keys for OpenRouter, possibly more), reads SQLite, reads memory. Pivots to your OpenRouter account. Mitigation: strong Hetzner password + 2FA, separate trust boundary.

**VPS-compromise via Hermes itself**: an attacker who can message your bot (would need your Telegram user ID or to be in `TELEGRAM_ALLOWED_USERS`) could prompt-inject Hermes to run shell commands, exfiltrate `.env`, etc. This is the *agent-shell-access blast radius* — the whole reason this box is single-tenant. Mitigation: keep `TELEGRAM_ALLOWED_USERS` to just you.

**OpenRouter breach**: their internal logs leak. 30 days of your conversations leak. Mitigation: opt out of logging.

**Model-provider data retention**: 30 days of your conversations sit at Anthropic/OpenAI. Could be subpoenaed. Mitigation: don't share things that would be problematic in a subpoena window.

**Memory drift**: Hermes' memory file persists and is re-read on every conversation. If you shared something private in a moment of frustration, it can be brought up later in unexpected contexts. Mitigation: audit and prune.

## What "max info" buys you vs. costs you

**Buys**:
- Hermes anticipates context (knows your projects, schedule, preferences)
- Can write in your voice
- Can plan around your life
- Produces output that sounds genuinely *you*
- All of the high-value user-story patterns (second-brain, content-in-your-voice, scheduled-briefings) depend on this

**Costs**:
- A multi-vendor dossier that grows over time
- Surprising context recall — Hermes brings up old conversations at unexpected moments (intended feature; sometimes uncomfortable)
- A high-value target if anyone ever wants to know what you think (jealous ex, hostile journalist, hiring committee, future legal opponent)
- Modeling that persists even after you'd want it gone — Hermes can autonomously write skills like "Benny prefers X, dislikes Y" that show up in every future session

For most personal-productivity use cases, you can get 80% of the value from sharing the relatively-safe 50% of personal context. The marginal info beyond that gives diminishing returns on utility but linear increase in breach impact.

## What to share / not share

See the README's "What to share with Hermes (and what not to)" section for the operational table. The short version:

- **Share**: work projects, technical preferences, schedule, reading interests, opinions on public topics, general relationship shape, goals.
- **Don't share**: banking specifics, medical history, legal matters, strong opinions about specific real people, others' secrets, anything you'd hate to see in court.

## Mitigations in detail

### 1. Verify OpenRouter isn't logging your inputs/outputs

Good news: OpenRouter's logging is **off by default**. There are two related toggles, both starting off; you just need to confirm they're still off (or opt them off if you previously opted in for the 1% discount).

- **Workspace Privacy** at https://openrouter.ai/workspaces/default/settings — the **"OpenRouter Use of Inputs/Outputs"** toggle. If on, OpenRouter retains your prompts/responses to improve their service. Default: **off**.
- **Workspace Observability** at https://openrouter.ai/workspaces/default/observability — the **"Private Input & Output Logging"** toggle. If on, OpenRouter stores your prompts/responses **for your own viewing** (your private logs). Default: **off**.

Both off ≡ OpenRouter retains nothing about your prompts beyond what the underlying model provider needs to serve the request. That's the privacy posture you want.

### 2. Pin to providers with explicit no-training policies

In `~/.hermes/config.yaml`, set `model.default` to a known-good provider:

- `anthropic/claude-sonnet-4` — Anthropic, no training on API inputs
- `anthropic/claude-opus-4` — same
- `openai/gpt-4o` — OpenAI, no training on API inputs

Avoid routing sensitive context through providers with unclear policies.

### 3. Audit Hermes' memory monthly

```
ssh hermes@hermes
cat ~/.hermes/MEMORY.md       # or wherever Hermes persists memory
ls -la ~/.hermes/skills/      # autonomously-generated skill files
```

Read what's there. Edit out anything you don't want persisted. Hermes will re-write the memory file naturally as you use it, so this is an ongoing pruning, not a one-time setup.

### 4. Never paste secrets into chat with Hermes

Same rule that applies when chatting with any LLM. If a secret needs to be on the box, write it directly to `.env` on the box, not via Telegram. Telegram has a copy, the LLM provider has a copy, and the Hermes memory file might have a copy.

### 5. Treat the Hetzner box as compromisable

Don't put anything on there that would also unlock other accounts. The box runs **only Hermes**:

- No AWS credentials
- No GitHub deploy keys
- No password reuse with critical accounts
- No Tailscale auth keys with broad ACLs (yet — see future-hardening)
- No SSH keys to your production systems

If Hermes (the agent, not the OS) gets prompt-injected into doing something hostile, the blast radius should be limited to the Hermes box itself.

### 6. Tailscale ACLs (future hardening)

Currently your tailnet trust is flat: Hermes box can reach any of your other devices via Tailscale. Eventually, scope a `tag:server` so Hermes can't initiate connections to `tag:laptop` or `tag:phone`. This is on the future-hardening list in `ops-runbook.md`.

### 7. Treat Hermes' memory as a journal

Before sharing something, ask: *would I write this in a paper journal someone might find?* If no, don't tell Hermes. This is the simplest mental model and produces the right answer most of the time.

## Honest summary

You're building a relationship with a thoughtful but slightly chatty colleague who lives in a multi-tenant pipeline. Share what makes them effective at helping you; withhold what you wouldn't want repeated.

Every few weeks, look at `~/.hermes/MEMORY.md` and ask: "would I be comfortable with this content leaking?" If the answer is no, edit the file. Hermes will respect the edit and re-curate going forward.

The infra is yours. The privacy posture is a daily choice.
