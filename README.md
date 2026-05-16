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
│   ├── prereqs.md           # Account + tooling checklist
│   ├── telegram-setup.md    # BotFather + user ID walkthrough
│   └── ops-runbook.md       # Lifecycle commands
├── scripts/
│   └── recover.sh           # Emergency recovery (rarely needed at level 3)
├── .env.example
├── Makefile
└── .gitignore
```

## Trust boundary

This box runs **only Hermes**. It is *not* a jumpbox, *not* a homelab, *not* a place to keep production credentials. Hermes is an LLM-driven agent with full shell access by design — anything on this host is reachable by the agent, including from your Telegram messages.

Resist the urge to put AWS creds, Audeos prod keys, GitHub deploy keys, or anything load-bearing on this machine. If you want a personal jumpbox, it's a sibling repo away.

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
