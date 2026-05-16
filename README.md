# hermes-infra

Self-hosted [Hermes Agent](https://github.com/NousResearch/hermes-agent) on a Hetzner VPS, accessible only via Tailscale. Infrastructure is split into three layers along their natural change cadences:

| Layer | Tools | Cadence | What it produces |
|---|---|---|---|
| **Image bake** | Packer + Ansible | Weekly–monthly | A versioned Hetzner snapshot with all binaries + config |
| **Provisioning** | OpenTofu | Per deploy | A Hetzner server booted from the latest snapshot |
| **Runtime config** | cloud-init | Per boot | Tailscale auth, API keys injected as secrets |

## Layout

```
.
├── packer/                  # Image build definition
│   ├── hermes.pkr.hcl       #   Builder + ansible provisioner wiring
│   └── variables.pkr.hcl    #   Hetzner build-VM settings
├── ansible/                 # Configuration management (run during bake)
│   ├── playbook.yml         #   Top-level play
│   ├── ansible.cfg          #   Defaults
│   ├── requirements.yml     #   Galaxy deps (currently none)
│   └── roles/
│       ├── common/          #     Base OS, users, SSH hardening
│       ├── tailscale/       #     Tailscale binary install (no auth)
│       └── hermes/          #     Hermes Agent install
├── terraform/               # Provisioning only — no baking
│   ├── data.tf              #   Snapshot lookup (by label)
│   ├── server.tf            #   Hetzner CPX21 from snapshot
│   ├── firewall.tf          #   Tailscale-only inbound
│   ├── variables.tf, ...
│   └── cloud-init.yaml.tftpl  # ~10 lines of runtime config
├── docs/
│   ├── prereqs.md                # Account + tooling checklist
│   ├── telegram-setup.md         # BotFather + user ID walkthrough
│   ├── ops-runbook.md            # Lifecycle commands
│   └── privacy-considerations.md # Data-flow + threat-model deep dive
├── .env.example
├── Makefile
└── .gitignore
```

## Trust boundary

This box runs **only Hermes**. It is *not* a jumpbox, *not* a homelab, *not* a place to keep production credentials. Hermes is an LLM-driven agent with full shell access by design — anything on this host is reachable by the agent, including from your Telegram messages.

Resist the urge to put AWS creds, production keys for your other projects, GitHub deploy keys, or anything load-bearing on this machine. If you want a personal jumpbox, it's a sibling repo away.

## Quickstart

1. Read [`docs/prereqs.md`](docs/prereqs.md) and gather: Hetzner token, Tailscale auth key, OpenRouter key, Telegram bot token + user ID.
2. `cp .env.example .env` and fill it in.
3. **Bake the image** (one-time, ~5-10 min):
   ```
   make image-init
   make image-build
   ```
4. **Provision the server** (~1 min):
   ```
   make tf-init
   make plan      # review
   make apply
   ```
5. Confirm the box appears in your tailnet at https://login.tailscale.com/admin/machines
6. `make ssh` (= `ssh hermes@hermes` over Tailscale).
7. Open Telegram, find your bot by username, message it — should reply via Hermes immediately.

Day-to-day, `make apply` is enough; the image is reused. Rebake only when:
- You want to bump Hermes Agent / Tailscale versions or any pinned Ansible role variable
- You change anything in `ansible/` roles
- It's been a few weeks and you want fresh OS-level security patches baked in

## Cost

| Item | Cost |
|---|---|
| Hetzner CPX21 server | ~€7.39/mo |
| Hetzner snapshot storage | ~€0.10/mo (~9 GB image) |
| Packer build VM (per rebake) | ~€0.01 per build (5-10 min of CPX21) |
| Tailscale Personal | Free (up to 100 devices) |
| Model API (OpenRouter) | Variable — set a monthly cap at Account → Limits |

**Total infra: ~€7.50/mo.** Model API spend depends on usage.

## Privacy & data flow

Every message you send Hermes touches **four distinct trust boundaries**: Telegram → your Hetzner VPS → OpenRouter → the actual model provider (Anthropic / DeepSeek / etc.). Each has its own data retention policy, jurisdiction, and breach history. Sharing with Hermes is not the same as writing in a private journal — it's writing in a multi-tenant pipeline.

| Layer | What they see | Retention | Real threat |
|---|---|---|---|
| **Telegram** | Every message body + metadata | Indefinitely on their servers. Bot chats are **not** end-to-end encrypted — only Secret Chats are, and bots can't use those. | Telegram account compromise; subpoena to Telegram |
| **Hetzner** (your VPS) | Cleartext messages, SQLite of every conversation, your memory file, your API keys | Until `make destroy` | German GDPR-bound provider; hypervisor-level access in theory |
| **OpenRouter** | Full prompt + response on every API call | 30 days default; disable in dashboard (Settings → Inference Privacy) | Their breach exposes everything |
| **Model provider** (Anthropic, etc.) | Your prompts including conversation history Hermes has accumulated | Anthropic/OpenAI: 30 days, no training on API inputs by default. DeepSeek + many Chinese providers: unclear, may train on inputs, subject to PRC data laws. | Provider breach; subpoena |
| **Hermes itself** (on your VPS) | Everything, forever, in `~/.hermes/sessions/` + memory file | Whatever you configure | Anyone who pwns the VM gets a structured profile of you |

The persistent piece is the dangerous piece. A single message is ephemeral; Hermes' memory file is a *cumulative dossier* that grows over time. The longer you use it, the higher the value of the data if any link in the chain breaches.

## What to share with Hermes (and what not to)

**Maximum info to Hermes = maximum utility AND maximum dossier risk.** They're the same axis. The marginal info beyond "what makes Hermes useful" gives diminishing returns on utility but linear increase in breach impact.

**Yes** (low regret):
- Your work projects, technical preferences, dev workflows
- Your schedule and recurring rituals
- Your reading interests, opinions on public topics
- Your goals and progress against them
- Lightweight financial framing ("I'm budgeting $X for hosting")
- *General* shape of your relationships ("my partner Sarah", "my friend Mike")

**No** (high regret):
- Banking, brokerage, crypto wallet specifics (account numbers, balances, seed phrases — *never* in chat)
- Medical history, current diagnoses, mental-health specifics
- Legal matters (active disputes, NDAs you're under, settlements)
- Strong opinions about specific real people — especially negative ones
- Secrets that aren't yours to share (other people's diagnoses, finances, etc.)
- Identifiers that would deanonymize you in a breach (SSN, passport #, mother's maiden name)
- Anything you'd be embarrassed to see in court / in a news article / in front of your family

**Probably no** (depends): romantic/sexual specifics, specific addresses (yours, family, friends), personal phone numbers of others, family-conflict details.

## Privacy mitigations

Things you can do that meaningfully shrink the surface area:

1. **Disable OpenRouter logging**: dashboard → Settings → Inference Privacy → opt out. Cuts one major retention point.
2. **Prefer providers with explicit no-training policies**: Anthropic and OpenAI paid API. Avoid routing sensitive context through DeepSeek or other models with unclear policies.
3. **Periodically audit Hermes' memory**: SSH in, read `~/.hermes/MEMORY.md` (or wherever Hermes persists memory), prune anything you don't want there. Make this a monthly habit.
4. **Never paste secrets into chat with Hermes** — same rule that applies to chatting with any LLM. If you need a secret on the box, write it directly to the runtime env file on the box, not via Telegram.
5. **Treat the Hetzner box as compromisable**: don't put anything on there that would also unlock other accounts. No AWS creds, no password reuse, no anything load-bearing for your other systems.
6. **Tailscale ACLs** (future hardening item — see `docs/ops-runbook.md`): limits what the box can reach from your tailnet, even if Hermes is compromised.
7. **Treat Hermes' memory as a journal**: ask yourself before sharing — *would I write this in a paper journal someone might find?* If no, don't tell Hermes.

For the full discussion of the data flow and threat scenarios, see the back-and-forth in `docs/privacy-considerations.md` (or open an issue if questions come up).
