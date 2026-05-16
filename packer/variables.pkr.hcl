variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token (Read & Write). Sourced from PKR_VAR_hcloud_token / env."
}

variable "build_location" {
  type        = string
  default     = "ash"
  description = "Hetzner location for the temporary build server. Match the production location to avoid image-transfer overhead."
}

variable "build_server_type" {
  type        = string
  default     = "cpx21"
  description = "Hetzner server type used for the build VM. cpx21 matches production for full fidelity (3 vCPU / 4 GB / 80 GB)."
}

variable "build_base_image" {
  type        = string
  default     = "ubuntu-24.04"
  description = "Base Hetzner image to bake on top of."
}
