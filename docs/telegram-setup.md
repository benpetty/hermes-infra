# Telegram setup

One-time creation of the bot and the allowlist. This whole flow takes ~3 minutes.

## Why Telegram (vs. Signal)

Telegram bots are first-class identities on the platform: distinct username, avatar, and bubble color in chats. Zero ambiguity about which messages are yours vs. the bot's. No daemon to run on the box. No phone number required for the bot. The bot's auth surface is a single revocable HTTP token, not a linked device. For a personal Hermes setup, this is what you want — most of the Hermes community runs Telegram for exactly these reasons.

## Step 1 — Create the bot via BotFather

In Telegram on your phone, find **@BotFather** (verified, has a blue checkmark) and message:

```
/newbot
```

BotFather will walk you through:
1. **Bot display name** — anything human-readable (e.g. `Hermes`).
2. **Bot username** — must be globally unique across Telegram and **must end in `bot`** (e.g. `bnpetty_hermes_bot`). This becomes `t.me/<username>` — how you find your bot.

When you're done, BotFather replies with a token like:

```
7234567890:AAEhBP8a7sN5Yz...
```

**This token is a credential.** Anyone with it can fully control your bot. Save it directly to your `.env` (or a password manager), never paste it into chat / Slack / email / git.

→ Set `TF_VAR_telegram_bot_token` in `.env`.

## Step 2 — Get your Telegram user ID

The bot will deny all incoming messages by default (good). To allow yourself, we need your numeric Telegram user ID.

In Telegram, find **@userinfobot** and message `/start`. It replies with your numeric ID (something like `123456789`). That number is stable for your Telegram account.

→ Set `TF_VAR_telegram_allowed_users` in `.env` (comma-separated if you want multiple users).

## Step 3 — Apply

If you've already applied tofu with these vars set, you're done — Hermes is already polling Telegram for messages. Open Telegram, search for your bot's `@username`, send a message. Hermes should reply within a few seconds.

If you haven't applied yet:

```bash
make apply
```

After the server comes up (~1 min), the Hermes gateway boots with Telegram enabled, registers as a long-poll client against Telegram's Bot API, and starts listening.

## Smoke test

DM your bot something like:

> what's the date

You should see a reply. If you don't, check the gateway logs:

```bash
ssh hermes@hermes
sudo journalctl -u hermes-gateway -n 50 --no-pager
```

Look for `Telegram platform enabled` near the top and any errors related to `TELEGRAM_BOT_TOKEN` or auth.

## Rotating the bot token

If the token ever leaks:

1. In Telegram, message **@BotFather** → `/revoke` → pick your bot. BotFather generates a fresh token.
2. Replace `TF_VAR_telegram_bot_token` in `.env`.
3. `make apply` — cloud-init re-writes `~/.hermes/.env` with the new token.
4. `sudo systemctl restart hermes-gateway` on the box.

The old token stops working the instant you revoke it.

## Adding more allowed users

Each user messages **@userinfobot** to get their numeric ID. Concatenate IDs with commas in `TF_VAR_telegram_allowed_users`:

```
TF_VAR_telegram_allowed_users=123456789,987654321
```

`make apply` to push the new allowlist; `sudo systemctl restart hermes-gateway` to re-read.

## Removing the bot entirely

To shut down the bot: message **@BotFather** → `/deletebot` → pick yours, follow prompts. The bot stops responding immediately and the username becomes unavailable for ~24 hours. (You can also just blank `TF_VAR_telegram_bot_token` and re-apply if you only want a temporary pause.)
