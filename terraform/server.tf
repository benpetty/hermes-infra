resource "hcloud_ssh_key" "admin" {
  count      = var.ssh_admin_key == "" ? 0 : 1
  name       = "${var.server_name}-admin"
  public_key = var.ssh_admin_key
}

resource "hcloud_server" "hermes" {
  name         = var.server_name
  server_type  = var.server_type
  image        = var.server_image
  location     = var.server_location
  ssh_keys     = var.ssh_admin_key == "" ? [] : [hcloud_ssh_key.admin[0].name]
  firewall_ids = [hcloud_firewall.hermes.id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    tailscale_auth_key = var.tailscale_auth_key
    openrouter_api_key = var.openrouter_api_key
    server_name        = var.server_name
  })

  labels = {
    role       = "hermes-agent"
    managed_by = "opentofu"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
