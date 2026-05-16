# Ops runbook

## Day-to-day

| Need to… | Command |
|---|---|
| Apply changes | `make apply` |
| Preview changes | `make plan` |
| SSH in | `make ssh` |
| Check outputs (IP, etc.) | `make status` |
| Reformat .tf files | `make fmt` |
| Tear it all down | `make destroy` |

## State

State is **local and gitignored** (`terraform/terraform.tfstate`). It contains all secrets in plaintext (Hetzner token, Tailscale auth key, API keys), so:

- Never commit it.
- Back it up if you care about not re-discovering things — easiest is `cp terraform/terraform.tfstate ~/Documents/hermes-infra-state-$(date +%F).backup` before destructive changes.
- If state is lost, `tofu import` can rebuild it from cloud reality, but it's tedious. Easier to `tofu destroy` (manually if needed) and re-apply.

If you want remote state later, options:
- Hetzner Storage Box with `s3` backend (Hetzner offers an S3-compatible endpoint).
- AWS S3 + DynamoDB lock table.

## Rotating credentials

### OpenRouter key
1. New key in https://openrouter.ai/keys (keep the same spend cap or raise it).
2. Update `TF_VAR_openrouter_api_key` in `.env`.
3. `make apply` — cloud-init re-runs and rewrites `~/.hermes-env`. (Confirm with `cat /home/hermes/.hermes-env` over SSH.)
4. Restart Hermes gateway: `hermes gateway restart`.
5. Revoke the old key in OpenRouter.

### Hetzner token
1. New token in Hetzner Console.
2. Replace `TF_VAR_hcloud_token` in `.env`.
3. `make plan` should show no changes — it's just auth.
4. Revoke the old one.

### Tailscale auth key
The auth key is one-time-use, so it's only relevant during initial provisioning. To re-key: rotate via the Tailscale admin console (machine settings → re-authorize).

## Recovery

### Box is broken / I want a fresh one

```bash
make destroy
make apply
```

Hermes' learning state (skills, memory, sessions in `~/.hermes/` on the VPS) is **wiped** by destroy. If you want to keep it: `rsync -avz hermes:.hermes/ ./hermes-state-backup/` first.

### Cloud-init failed on first boot

```bash
ssh hermes
sudo cat /var/log/hermes-bootstrap.log
sudo tail -f /var/log/cloud-init-output.log
```

To re-run bootstrap manually:

```bash
sudo /opt/hermes-bootstrap/run.sh
```

### Tailscale isn't appearing in admin console

The auth key may have expired (90-day default). Generate a new one, update `.env`, and re-run cloud-init or run `tailscale up --authkey=...` manually on the box.

### I lost SSH access

If Tailscale is healthy but SSH fails: log in via Tailscale admin console "SSH" feature in the browser, or use Hetzner web console (`console.hetzner.cloud` → server → Console).

## Cost-watching

- Hetzner: monthly invoice; CPX21 is ~€7.39/mo.
- OpenRouter: dashboard shows real-time spend (Account → Limits sets the monthly cap; do this if you haven't).
- Tailscale: free.

If costs surprise you, the most likely culprit is a Hermes cron escalating to Sonnet for low-stakes turns. Check `~/.hermes/sessions/` on the box for recent activity.

## Future hardening (not done yet)

- [ ] Attach a tofu-generated throwaway SSH key (`tls_private_key` resource → `hcloud_ssh_key` → server `ssh_keys`) to suppress Hetzner's root-password provisioning email. Note: requires server replacement on existing infra, so do this at the next planned destroy/apply.
- [ ] Tailscale ACLs scoping `tag:server` so this box can't reach `tag:laptop`.
- [ ] Hetzner snapshot schedule (daily) for the boot volume — covers Hermes state recovery.
- [ ] Remote tofu state on Hetzner Storage Box.
- [ ] Alertmanager / Healthchecks.io ping for the Hermes gateway being alive.
- [ ] Move the OpenRouter key into a key-vault flow (1Password CLI → cloud-init).
