# Prereqs

Accounts to create and credentials to gather before `tofu apply`.

## 1. Hetzner Cloud

1. Sign up: https://accounts.hetzner.com/signUp
2. Create a project (e.g. "personal-infra").
3. In that project: **Security → API Tokens → Generate API Token**.
   - Permissions: **Read & Write**
   - Description: "hermes-infra opentofu"
4. Copy the token. You will not see it again.
   - → `TF_VAR_hcloud_token` in `.env`

## 2. Tailscale

1. Sign up at https://tailscale.com (free Personal plan, no card required).
2. Install Tailscale on the devices you'll SSH from (Mac via Homebrew or App Store, iOS/Android app, etc.). Sign in.
3. Generate an auth key for the VPS: https://login.tailscale.com/admin/settings/keys → **Generate auth key…**
   - Reusable: **OFF** (one-time)
   - Ephemeral: **OFF** (the box should stay registered after reboots)
   - Pre-approved: **ON** (avoids a manual approval step in admin console)
   - Tags: leave blank for now (can add `tag:server` later once an ACL is written)
   - Expiration: 90 days is fine; rotate then.
   - → `TF_VAR_tailscale_auth_key` in `.env`

## 3. OpenRouter

Single provider for everything Hermes calls — DeepSeek V4 for default routing, Claude Sonnet 4.6 (via OpenRouter) for high-stakes escalation, plus GPT/Gemini/Llama on demand. No separate Anthropic key needed; Sonnet is reachable as `anthropic/claude-sonnet-4` through OpenRouter.

1. Sign up: https://openrouter.ai
2. Add credit (start with $15-25 — comfortably covers initial usage including some Sonnet escalations).
3. Set a monthly spend cap: **Account → Limits**.
4. Create a key: https://openrouter.ai/keys
   - → `TF_VAR_openrouter_api_key` in `.env`

## 4. Telegram bot

The user-facing chat surface. See [`telegram-setup.md`](telegram-setup.md) for the full walkthrough; in short:

1. In Telegram, message **@BotFather** with `/newbot`. Provide a display name (e.g. `Hermes`) and a globally-unique username ending in `bot` (e.g. `bnpetty_hermes_bot`).
2. BotFather returns an HTTP API token. Copy it.
   - → `TF_VAR_telegram_bot_token` in `.env`
3. Get your numeric Telegram user ID — message **@userinfobot** with `/start`. It replies with your numeric ID.
   - → `TF_VAR_telegram_allowed_users` in `.env` (comma-separated if you want multiple users)

## 5. Local tooling

Install the three CLIs the workflow uses:

```bash
brew install opentofu hashicorp/tap/packer ansible
```

Verify:

```bash
tofu version    # >= 1.6.0
packer version  # >= 1.10.0
ansible --version | head -1  # >= 2.16
```

Why each one:
- **OpenTofu** — provisions infrastructure
- **Packer** — bakes the OS image
- **Ansible** — configures the image during the bake

## 6. (Optional) Emergency SSH key

Tailscale SSH is the primary access path. If you want a public-port-22 fallback for emergencies, generate a key and put the public part in `TF_VAR_ssh_admin_key`. You will *also* need to add a public SSH rule in `terraform/firewall.tf` — by default the firewall does **not** expose port 22 publicly.

For most setups, leave this blank.

---

## Sanity check

Once `.env` is filled in:

```bash
make image-validate     # ansible + packer syntax check
make tf-validate        # tofu syntax + type check
```

Both should be silent on success. Then proceed to image bake + tofu apply (see the README quickstart).
