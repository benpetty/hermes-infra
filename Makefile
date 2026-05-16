.PHONY: help \
        tf-init tf-fmt tf-validate plan apply destroy refresh status ssh \
        image-init image-validate image-build \
        ansible-lint ansible-syntax

TF_DIR     := terraform
PACKER_DIR := packer
ANSIBLE_DIR := ansible

# Auto-load .env so TF_VAR_* and PKR_VAR_* are exported. Falls back silently.
ifneq (,$(wildcard ./.env))
	include .env
	export
endif

# Packer reads PKR_VAR_* env vars. We declare `hcloud_token` once in .env
# as TF_VAR_hcloud_token (for tofu) — alias it for Packer here.
export PKR_VAR_hcloud_token = $(TF_VAR_hcloud_token)

help:
	@echo "── Image (Packer + Ansible) ─────────────────────────────"
	@echo "  image-init     — install Packer plugins"
	@echo "  image-validate — syntax-check Packer + Ansible"
	@echo "  image-build    — bake a new snapshot (~10 min)"
	@echo ""
	@echo "── Infrastructure (OpenTofu) ───────────────────────────"
	@echo "  tf-init        — install tofu providers"
	@echo "  tf-fmt         — auto-format .tf files"
	@echo "  tf-validate    — syntax + type-check"
	@echo "  plan           — preview changes"
	@echo "  apply          — provision/update infra (requires baked image)"
	@echo "  destroy        — tear it all down"
	@echo "  refresh        — sync state with reality (rare)"
	@echo ""
	@echo "── Live box ────────────────────────────────────────────"
	@echo "  status         — show server outputs"
	@echo "  ssh            — ssh hermes@hermes (Tailscale)"

# ── Image (Packer + Ansible) ───────────────────────────────────────

image-init:
	cd $(PACKER_DIR) && packer init .

image-validate:
	cd $(PACKER_DIR) && packer validate .
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbook.yml

image-build:
	cd $(PACKER_DIR) && packer build .

ansible-syntax:
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbook.yml

# ── Infrastructure (OpenTofu) ──────────────────────────────────────

tf-init:
	cd $(TF_DIR) && tofu init

tf-fmt:
	cd $(TF_DIR) && tofu fmt -recursive

tf-validate:
	cd $(TF_DIR) && tofu validate

plan:
	cd $(TF_DIR) && tofu plan

apply:
	cd $(TF_DIR) && tofu apply

destroy:
	cd $(TF_DIR) && tofu destroy

refresh:
	cd $(TF_DIR) && tofu apply -refresh-only

# ── Live box ───────────────────────────────────────────────────────

status:
	cd $(TF_DIR) && tofu output

ssh:
	ssh hermes@hermes
