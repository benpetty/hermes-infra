# hermes-infra

OpenTofu config that provisions a single-tenant VPS for [Hermes Agent](https://github.com/NousResearch/hermes-agent), accessible only over Tailscale.

## Layout

```
.
├── terraform/              # OpenTofu config
│   ├── versions.tf         # Provider pins
│   ├── providers.tf        # Provider auth
│   ├── variables.tf        # Inputs (all sensitive vars come from .env)
│   ├── server.tf           # The Hetzner CX22 + ssh_key + cloud-init wiring
│   ├── firewall.tf         # Tailscale UDP + ICMP only; nothing else inbound
│   ├── outputs.tf          # Server IP, ssh hint
│   └── cloud-init.yaml.tftpl  # First-boot bootstrap template
├── docs/
│   ├── prereqs.md          # Accounts and keys you need before applying
│   ├── signal-linking.md   # One-time Signal device-link runbook
│   └── ops-runbook.md      # Apply / rotate / destroy / recover
├── .env.example            # Variable template
├── Makefile                # Wraps `tofu` lifecycle
└── .gitignore
```

## Trust boundary

This box runs **only Hermes**. It is *not* a jumpbox, *not* a homelab, *not* a place to keep production credentials. Hermes is an LLM-driven agent with full shell access by design — anything on this host is reachable by the agent, including from your Signal messages.

Resist the urge to put AWS creds, Audeos prod keys, GitHub deploy keys, or anything load-bearing on this machine. If you want a personal jumpbox, it's a second `tofu apply` away in a sibling repo.

## Quickstart

1. Read [`docs/prereqs.md`](docs/prereqs.md) and gather: Hetzner token, Tailscale auth key, OpenRouter key.
2. `cp .env.example .env` and fill it in.
3. `make init && make plan && make apply`
4. Wait ~3-5 min for cloud-init (`tofu apply` returns once the server is created, but bootstrap continues in the background).
5. Confirm the box appears in your tailnet at https://login.tailscale.com/admin/machines
6. `ssh hermes` should just work (Tailscale SSH).
7. Follow [`docs/signal-linking.md`](docs/signal-linking.md) for the one-time Signal QR step.

## Cost

Roughly **€7.39/mo** for the CPX21 server + Tailscale Personal (free up to 100 devices). Model API spend is separate via OpenRouter — set a monthly spend limit in your OpenRouter account settings (Account → Limits).
