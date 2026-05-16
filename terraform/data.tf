# Look up the most recent Packer-baked snapshot. The selector matches
# the `purpose=hermes-agent` label set by packer/hermes.pkr.hcl. If no
# such snapshot exists (e.g., before the first `make image-build`),
# this data source errors loudly — that's the desired behavior.
data "hcloud_image" "hermes" {
  with_selector     = "purpose=hermes-agent"
  most_recent       = true
  with_architecture = "x86"
}
