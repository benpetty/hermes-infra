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

## 4. OpenTofu (local)

```bash
brew install opentofu      # macOS
```

Verify: `tofu version` should show `>= 1.6.0`.

## 5. (Optional) Emergency SSH key

Tailscale SSH is the primary access path. If you want a public-port-22 fallback for emergencies, generate a key and put the public part in `TF_VAR_ssh_admin_key`. You will *also* need to add a public SSH rule in `terraform/firewall.tf` — by default the firewall does **not** expose port 22 publicly.

For most setups, leave this blank.

---

## Sanity check

Once `.env` is filled in:

```bash
make validate    # syntax check, no API calls
make init        # downloads Hetzner provider
make plan        # shows what would be created — review this!
```

If `plan` looks right, run `make apply`.
