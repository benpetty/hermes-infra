# Ops runbook

## Day-to-day

| Need to… | Command |
|---|---|
| Bake a new image | `make image-build` |
| Preview tofu changes | `make plan` |
| Apply tofu changes | `make apply` |
| SSH in | `make ssh` |
| Check outputs (IP, etc.) | `make status` |
| Reformat .tf files | `make tf-fmt` |
| Tear it all down | `make destroy` |

## State

State is **local and gitignored** (`terraform/terraform.tfstate`). It contains all secrets in plaintext (Hetzner token, Tailscale auth key, API keys, Telegram bot token), so:

- Never commit it.
- Back it up if you care about not re-discovering things — easiest is `cp terraform/terraform.tfstate ~/Documents/hermes-infra-state-$(date +%F).backup` before destructive changes.
- If state is lost, `tofu import` can rebuild it from cloud reality, but it's tedious. Easier to `tofu destroy` (manually if needed) and re-apply.

If you want remote state later, options:
- Hetzner Storage Box with `s3` backend (Hetzner offers an S3-compatible endpoint).
- AWS S3 + DynamoDB lock table.

## Image lifecycle

| Need to… | Command | Notes |
|---|---|---|
| Bake a new image | `make image-build` | ~5-10 min. Spins up a temp CPX21, runs Ansible, snapshots, destroys temp. |
| Validate before baking | `make image-validate` | Syntax-check Packer + Ansible. No API calls. |
| Use latest image | (automatic) | Tofu's `data.hcloud_image.hermes` picks the most-recent snapshot labeled `purpose=hermes-agent` on every plan/apply. |
| Pin a specific image | Manual | Edit `terraform/data.tf` to filter by `built_at` label or hardcode an ID. Rare. |
| List snapshots | Hetzner Cloud Console | https://console.hetzner.cloud → Images → Snapshots, filtered by label `purpose=hermes-agent`. |
| Prune old snapshots | Hetzner Cloud Console | Each snapshot is ~€0.10/mo. Keep the last 1-2 for rollback. Delete in the console UI. |

**When to rebake:**
- Bumping Hermes Agent (vendor's install.sh always pulls latest)
- Changing any Ansible role (`ansible/roles/**`)
- Pulling fresh OS-level security patches (every few weeks is a reasonable cadence)

After a rebake, the next `make apply` will see the new snapshot and **replace the running server**. To pin against this and rollback to a previous image, delete the new snapshot or edit `terraform/data.tf` to filter explicitly.

## Rotating credentials

### OpenRouter key
1. New key in https://openrouter.ai/keys (keep the same spend cap or raise it).
2. Update `TF_VAR_openrouter_api_key` in `.env`.
3. `make apply` — cloud-init re-runs and rewrites `~/.hermes/.env`. (Confirm with `sudo grep OPENROUTER ~/.hermes/.env` over SSH.)
4. Restart the gateway: `sudo systemctl restart hermes-gateway`.
5. Revoke the old key in OpenRouter.

### Telegram bot token
1. In Telegram, message **@BotFather** → `/revoke` → pick your bot. New token returned.
2. Update `TF_VAR_telegram_bot_token` in `.env`.
3. `make apply`.
4. `sudo systemctl restart hermes-gateway`.

### Hetzner token
1. New token in Hetzner Console.
2. Replace `TF_VAR_hcloud_token` in `.env`.
3. `make plan` should show no changes — it's just auth.
4. Revoke the old one.

### Tailscale auth key
The auth key is one-time-use, so it's only relevant during initial provisioning or when re-creating the server. To re-key: rotate via the Tailscale admin console (machine settings → re-authorize).

## Recovery

### Box is broken / I want a fresh one

```bash
make destroy
make apply
```

Hermes' learning state (skills, memory, sessions in `~/.hermes/` on the VPS) is **wiped** by destroy. If you want to keep it: `rsync -avz hermes@hermes:.hermes/ ./hermes-state-backup/` first.

### Cloud-init failed on first boot

At level 3, cloud-init does very little — just inject secrets and `tailscale up`. If it fails, the box is reachable via the Hetzner web console (`console.hetzner.cloud` → server → Console). Common causes:

- **Tailscale auth key expired or invalid** — check the admin console; regenerate, update `.env`, re-apply.
- **OpenRouter key / Telegram bot token typo** — fix `.env`, re-apply (cloud-init re-writes `~/.hermes/.env`).

When the image itself is suspect (something went wrong during the last bake), the right fix is `make image-build` to produce a fresh snapshot, then `make apply` — never patch the running box by hand. The image is the source of truth.

### Tailscale isn't appearing in admin console

The auth key may have expired (90-day default). Generate a new one, update `.env`, and re-apply. Or SSH in via Hetzner web console and run `tailscale up --authkey=...` manually.

### I lost SSH access

If Tailscale is healthy but SSH fails: log in via Tailscale admin console "SSH" feature in the browser, or use Hetzner web console (`console.hetzner.cloud` → server → Console).

## Cost-watching

- Hetzner: monthly invoice; CPX21 is ~€7.39/mo, snapshot storage ~€0.10/mo per image.
- OpenRouter: dashboard shows real-time spend (Account → Limits sets the monthly cap; do this if you haven't).
- Tailscale: free.
- Telegram: free.

If costs surprise you, the most likely culprit is a Hermes cron escalating to Sonnet for low-stakes turns. Check `~/.hermes/sessions/` on the box for recent activity.

## Future hardening (not done yet)

- [x] ~~Move install logic into Ansible roles, bake with Packer~~ (done — moved from cloud-init-in-yaml shell to level 3)
- [x] ~~Swap Signal for Telegram~~ (done — Telegram has first-class bot identity, no daemon, no phone number)
- [ ] Attach a tofu-generated throwaway SSH key (`tls_private_key` resource → `hcloud_ssh_key` → server `ssh_keys`) to suppress Hetzner's root-password provisioning email. Note: requires server replacement on existing infra, so do this at the next planned destroy/apply.
- [ ] Tailscale ACLs scoping `tag:server` so this box can't reach `tag:laptop`.
- [ ] Snapshot retention policy — currently we keep all baked images; should prune to last 2-3.
- [ ] Remote tofu state on Hetzner Storage Box.
- [ ] Alertmanager / Healthchecks.io ping for the Hermes gateway being alive.
- [ ] Move the OpenRouter key into a key-vault flow (1Password CLI → cloud-init).
- [ ] Ansible-lint + Packer linter in CI before allowing rebakes.
