variable "hcloud_token" {
  description = "Hetzner Cloud API token (Read & Write)."
  type        = string
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Tailscale one-time auth key from https://login.tailscale.com/admin/settings/keys."
  type        = string
  sensitive   = true
}

variable "openrouter_api_key" {
  description = "OpenRouter API key — Hermes' default model provider."
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token from @BotFather. Used by the Hermes messaging gateway."
  type        = string
  sensitive   = true
}

variable "telegram_allowed_users" {
  description = "Comma-separated Telegram numeric user IDs allowed to message the bot. Get yours from @userinfobot."
  type        = string
  sensitive   = true
}

variable "default_model" {
  description = "Default LLM model identifier passed to `hermes config set model.default`. Use OpenRouter IDs (e.g. anthropic/claude-haiku-4-5, anthropic/claude-sonnet-4-5, deepseek/deepseek-chat-v3.1). Hermes' built-in default is Opus 4.6 which is ~10× more expensive than Haiku for ambient chat; override to something appropriate for your workload."
  type        = string
}

variable "ssh_admin_key" {
  description = "Optional emergency SSH public key. Tailscale SSH is the primary access path; leave blank unless you want a public-port-22 fallback. NOTE: even with a key, the firewall does not open port 22 by default — you would need to add a rule in firewall.tf."
  type        = string
  default     = ""
}

variable "server_name" {
  description = "Hostname and Hetzner resource name."
  type        = string
  default     = "hermes"
}

variable "server_type" {
  description = "Hetzner server type. cpx21 = 3 vCPU AMD EPYC shared / 4 GB RAM / 80 GB disk. Note: the CX (Intel) and CAX (ARM) lines are EU-only; US locations (ash/hil) only offer CPX and CCX."
  type        = string
  default     = "cpx21"
}

variable "server_location" {
  description = "Hetzner location: ash (US-East/Ashburn), hil (US-West/Hillsboro), nbg/fsn (DE), hel (FI), sin (SG)."
  type        = string
  default     = "ash"
}

# Note: there is no `server_image` variable here. The image is resolved
# automatically by the data "hcloud_image" "hermes" source in data.tf,
# which selects the most recent snapshot labeled purpose=hermes-agent.
# To use a different image, build a new one with packer; this query then
# picks it up on the next apply.
