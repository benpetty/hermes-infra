# Hermes is reached only via Tailscale. The public surface is therefore
# minimal: Tailscale's NAT-traversed UDP port and ICMP for diagnostics.
# Everything else (SSH, HTTP, Hermes APIs) lives on the tailnet.
resource "hcloud_firewall" "hermes" {
  name = "${var.server_name}-fw"

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "41641"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Tailscale direct (NAT-traversed UDP)"
  }

  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "ICMP echo for diagnostics"
  }

  # Outbound is allowed by default in Hetzner Cloud firewalls.
}
