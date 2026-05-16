output "server_id" {
  description = "Hetzner server ID."
  value       = hcloud_server.hermes.id
}

output "server_ipv4" {
  description = "Public IPv4. Diagnostics only — SSH happens over Tailscale."
  value       = hcloud_server.hermes.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6."
  value       = hcloud_server.hermes.ipv6_address
}

output "tailscale_admin_url" {
  description = "After ~2-5 min the box appears here under the configured hostname."
  value       = "https://login.tailscale.com/admin/machines"
}

output "ssh_command" {
  description = "Once Tailscale is up locally, this should resolve and connect. The `hermes@` user prefix is required because Tailscale SSH otherwise tries to log in as your local Mac user, which doesn't exist on the box."
  value       = "ssh hermes@${var.server_name}"
}
