packer {
  required_version = ">= 1.10.0"

  required_plugins {
    hcloud = {
      version = ">= 1.6.0"
      source  = "github.com/hetznercloud/hcloud"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

locals {
  # Timestamped name for human readability. Tofu looks up by label, not name,
  # so this is purely for the Hetzner UI / log readability.
  snapshot_name = "hermes-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  # Labels are what tofu's data "hcloud_image" filters on.
  # `purpose = hermes-agent` selects only our images and ignores any other
  # snapshots in the project. `built_at` is informational.
  snapshot_labels = {
    purpose  = "hermes-agent"
    built_at = formatdate("YYYY-MM-DD", timestamp())
    built_by = "packer"
  }
}

source "hcloud" "hermes" {
  token           = var.hcloud_token
  image           = var.build_base_image
  location        = var.build_location
  server_type     = var.build_server_type
  ssh_username    = "root"
  snapshot_name   = local.snapshot_name
  snapshot_labels = local.snapshot_labels

  # Labels on the temp build VM (useful for filtering it out of dashboards).
  server_labels = {
    role    = "packer-builder"
    purpose = "hermes-agent-bake"
  }
}

build {
  name    = "hermes"
  sources = ["source.hcloud.hermes"]

  # Wait for cloud-init to finish on the fresh base image before Ansible
  # starts apt operations — otherwise apt's lock can collide.
  provisioner "shell" {
    inline = [
      "cloud-init status --wait || true",
      "apt-get update -y",
    ]
  }

  provisioner "ansible" {
    playbook_file = "${path.root}/../ansible/playbook.yml"
    user          = "root"

    # OpenSSH 9.x removed SCP protocol; force legacy mode so the
    # Ansible provisioner's file transfers work against the temp VM.
    extra_arguments = [
      "--scp-extra-args", "'-O'",
    ]
  }

  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
  }
}
