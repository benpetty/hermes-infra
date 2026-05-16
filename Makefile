.PHONY: help init fmt validate plan apply destroy ssh status console refresh

TF_DIR := terraform

# Auto-load .env so TF_VAR_* are exported. Falls back silently if no file.
ifneq (,$(wildcard ./.env))
	include .env
	export
endif

help:
	@echo "make init      — install providers"
	@echo "make fmt       — auto-format .tf files"
	@echo "make validate  — syntax + type-check (no creds needed)"
	@echo "make plan      — preview changes"
	@echo "make apply     — provision/update infrastructure"
	@echo "make destroy   — tear it all down"
	@echo "make ssh       — ssh hermes@hermes (assumes Tailscale is up locally)"
	@echo "make status    — show server, IP, Tailscale hint"
	@echo "make refresh   — sync state with reality (rare)"

init:
	cd $(TF_DIR) && tofu init

fmt:
	cd $(TF_DIR) && tofu fmt -recursive

validate:
	cd $(TF_DIR) && tofu validate

plan:
	cd $(TF_DIR) && tofu plan

apply:
	cd $(TF_DIR) && tofu apply

destroy:
	cd $(TF_DIR) && tofu destroy

refresh:
	cd $(TF_DIR) && tofu apply -refresh-only

status:
	cd $(TF_DIR) && tofu output

ssh:
	ssh hermes@hermes
