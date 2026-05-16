# Signal linking

One-time manual step after `tofu apply` succeeds. Takes ~5 min.

## Background

`signal-cli` operates as a **linked secondary device** on your existing personal Signal account — same model as Signal Desktop. Your phone stays primary. The bot does not need its own phone number.

This step cannot be automated by tofu because the linking happens via QR code displayed in your terminal, which you scan with your phone's Signal app.

## Steps

### 1. SSH in

```bash
ssh hermes@hermes
```

(Assumes Tailscale is running on your local machine and the box appears in your admin console. The `hermes@` user prefix is required — Tailscale SSH otherwise tries to log in as your local Mac user, which doesn't exist on the box. To make plain `ssh hermes` work, add a `User hermes` entry for the `hermes` host in your local `~/.ssh/config`.)

### 2. Confirm bootstrap finished

```bash
ls /opt/hermes-bootstrap/done   # exists when cloud-init's run.sh completed
tail -f /var/log/hermes-bootstrap.log    # live log if still running
```

### 3. Initiate the link

```bash
signal-cli link -n "HermesAgent"
```

This prints a `tsdevice:/?...` URL and a QR code to your terminal.

### 4. Scan from your phone

On your phone:

1. Open Signal.
2. **Settings → Linked Devices → Link New Device** (or the `+` icon).
3. Point your camera at the QR code in the terminal.

The terminal will print confirmation that linking succeeded and exit. Take note of the **Signal phone number** — it's your existing personal Signal number in E.164 format (e.g. `+15551234567`).

### 5. Sanity check signal-cli

Send yourself a message from the bot:

```bash
signal-cli -a +15551234567 send -m "Hermes Agent linked successfully" +15551234567
```

You should receive it on your phone.

### 6. Configure Hermes' Signal gateway

```bash
hermes setup gateway
```

When prompted:
- Platform: **Signal**
- `SIGNAL_HTTP_URL`: `http://127.0.0.1:8080`
- `SIGNAL_ACCOUNT`: your `+15551234567`
- `SIGNAL_ALLOWED_USERS`: `+15551234567` (your number — restricts the bot to only respond to you)
- `SIGNAL_ALLOW_ALL_USERS`: **false**

### 7. Start signal-cli daemon

Hermes talks to signal-cli over its HTTP daemon. Run it as a systemd service so it stays up:

```bash
sudo tee /etc/systemd/system/signal-cli.service >/dev/null <<'EOF'
[Unit]
Description=signal-cli daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=hermes
ExecStart=/usr/local/bin/signal-cli -a +15551234567 daemon --http 127.0.0.1:8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now signal-cli
sudo systemctl status signal-cli
```

Replace `+15551234567` with your real number in the unit file.

### 8. Install and start the Hermes gateway

```bash
hermes gateway install
hermes gateway start
hermes gateway status
```

### 9. Smoke test

DM your Hermes from Signal: `what's the date?`

You should see a reply within a few seconds.

## Troubleshooting

- **No reply, no error**: `journalctl -u hermes-gateway -f` and `journalctl -u signal-cli -f`. Most failures here are auth-related (`SIGNAL_ALLOWED_USERS` mismatch).
- **Duplicate replies**: per Hermes docs, ensure only one `signal-cli` instance is listening on your account at a time. If you ran `signal-cli` interactively earlier and it's still alive, kill it.
- **QR code expired**: the link URL has a short TTL. Re-run `signal-cli link` and scan promptly.
- **Phone number mismatch**: signal-cli uses your *Signal-registered* number, not necessarily your current SIM. Check Signal app → Settings → Account.
