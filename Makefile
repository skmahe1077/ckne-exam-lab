\
# ==============================================================================
# CKNE Hands-On Practice
# ==============================================================================
SHELL := /bin/bash
.DEFAULT_GOAL := help

KUBEADM_DIR := kubeadm-setup
LAB ?=
LEVEL ?= 1
LAB_DIR := $(shell [ -n "$(LAB)" ] && find labs -mindepth 2 -maxdepth 2 -type d -iname "$(LAB)" 2>/dev/null | head -n1)

.PHONY: help \
	aws-prerequisites aws-create aws-status aws-stop aws-start aws-destroy-dry-run aws-destroy \
	cluster-bootstrap cluster-verify cluster-reset kubeconfig \
	addons-install addons-verify \
	start validate cleanup reset learn exam hint solution \
	active-labs release-stale-lock \
	mock-exam-1 mock-exam-2 mock-exam-3 \
	shellcheck-all bash-syntax-check

help:
	@echo "CKNE Hands-On Practice — common targets"
	@echo ""
	@echo "  Infrastructure:"
	@echo "    make aws-prerequisites        Check local tools + AWS credentials"
	@echo "    make aws-create               Create AWS infrastructure (idempotent)"
	@echo "    make aws-status               Show status of project EC2 instances"
	@echo "    make aws-stop / aws-start     Stop / start project instances"
	@echo "    make aws-destroy-dry-run      Show what teardown would delete"
	@echo "    make aws-destroy              Destroy AWS infrastructure (confirms)"
	@echo ""
	@echo "  Cluster:"
	@echo "    make cluster-bootstrap        Bootstrap Kubernetes on the 3 nodes"
	@echo "    make cluster-verify           Verify cluster + add-on health"
	@echo "    make cluster-reset            kubeadm reset on all nodes (keeps EC2)"
	@echo "    make kubeconfig               Download kubeconfig via SSM"
	@echo "    make addons-install           Install shared cluster add-ons"
	@echo "    make addons-verify            Alias for cluster-verify"
	@echo ""
	@echo "  Labs (LAB=<task-id>, e.g. LAB=CNI-01):"
	@echo "    make start LAB=..             Run the lab's setup.sh"
	@echo "    make validate LAB=..          Run the lab's validate.sh"
	@echo "    make cleanup LAB=..           Run the lab's cleanup.sh"
	@echo "    make reset LAB=..             cleanup -> setup again"
	@echo "    make learn LAB=..             Show concept + task + hints/solution gating"
	@echo "    make exam LAB=..              Show task only (no hints/solution)"
	@echo "    make hint LAB=.. LEVEL=1       Show hint at LEVEL"
	@echo "    make solution LAB=..          Show solution"
	@echo "    make active-labs               List labs currently holding a shared lock"
	@echo "    make release-stale-lock LAB=..  Force-release a lock owned by LAB"
	@echo ""
	@echo "  Mock exams:"
	@echo "    make mock-exam-1 / -2 / -3     Run mock exam 1 / 2 / 3"
	@echo ""
	@echo "  Quality:"
	@echo "    make bash-syntax-check        bash -n every .sh file"
	@echo "    make shellcheck-all           shellcheck every .sh file (if installed)"

# ── AWS infrastructure ────────────────────────────────────────────────────────
aws-prerequisites:
	@command -v aws >/dev/null || (echo "aws CLI not found" && exit 1)
	@command -v jq >/dev/null || (echo "jq not found" && exit 1)
	@command -v envsubst >/dev/null || (echo "envsubst not found (install gettext)" && exit 1)
	@aws sts get-caller-identity --output table

aws-create:
	./$(KUBEADM_DIR)/aws-infra-setup.sh

aws-status:
	./$(KUBEADM_DIR)/aws-infra-status.sh

aws-stop:
	./$(KUBEADM_DIR)/aws-infra-stop.sh

aws-start:
	./$(KUBEADM_DIR)/aws-infra-start.sh

aws-destroy-dry-run:
	./$(KUBEADM_DIR)/aws-infra-down.sh --dry-run

aws-destroy:
	./$(KUBEADM_DIR)/aws-infra-down.sh --confirm

# ── Cluster ────────────────────────────────────────────────────────────────────
cluster-bootstrap:
	./$(KUBEADM_DIR)/cluster-bootstrap.sh

cluster-verify:
	./$(KUBEADM_DIR)/verify-cluster.sh

cluster-reset:
	./$(KUBEADM_DIR)/cluster-reset.sh

kubeconfig:
	./$(KUBEADM_DIR)/download-kubeconfig.sh

addons-install:
	./$(KUBEADM_DIR)/install-addons.sh

addons-verify: cluster-verify

# ── Labs ───────────────────────────────────────────────────────────────────────
define require_lab
	@if [ -z "$(LAB)" ]; then echo "Usage: make $(1) LAB=<task-id>  (e.g. LAB=CNI-01)"; exit 1; fi
	@if [ -z "$(LAB_DIR)" ]; then echo "No lab directory found matching LAB=$(LAB) under labs/"; exit 1; fi
endef

start:
	$(call require_lab,start)
	"$(LAB_DIR)/setup.sh"

validate:
	$(call require_lab,validate)
	"$(LAB_DIR)/validate.sh"

cleanup:
	$(call require_lab,cleanup)
	"$(LAB_DIR)/cleanup.sh"

reset:
	$(call require_lab,reset)
	"$(LAB_DIR)/reset.sh"

learn:
	$(call require_lab,learn)
	@echo "=============================================================="
	@echo " CONCEPT"
	@echo "=============================================================="
	@cat "$(LAB_DIR)/concept.md"
	@echo ""
	@echo "=============================================================="
	@echo " TASK"
	@echo "=============================================================="
	@cat "$(LAB_DIR)/task.md"
	@echo ""
	@echo "=============================================================="
	@echo " QUICK REFERENCE"
	@echo "=============================================================="
	@cat "$(LAB_DIR)/quick-reference.md"
	@echo ""
	@echo "Run 'make hint LAB=$(LAB) LEVEL=1' for a hint, or 'make solution LAB=$(LAB)' after attempting."

exam:
	$(call require_lab,exam)
	@echo "=============================================================="
	@echo " TASK (exam mode — no hints or solution shown)"
	@echo "=============================================================="
	@cat "$(LAB_DIR)/task.md"
	@echo ""
	@echo "=============================================================="
	@echo " QUICK REFERENCE"
	@echo "=============================================================="
	@cat "$(LAB_DIR)/quick-reference.md"
	@echo ""
	@echo "Run 'make validate LAB=$(LAB)' when ready."

hint:
	$(call require_lab,hint)
	@shared/scripts/show-hint.sh "$(LAB_DIR)" "$(LEVEL)"

solution:
	$(call require_lab,solution)
	@cat "$(LAB_DIR)/solution.md"

active-labs:
	@shared/scripts/lock.sh list

release-stale-lock:
	$(call require_lab,release-stale-lock)
	@shared/scripts/lock.sh release-lab "$(LAB)"

# ── Mock exams ─────────────────────────────────────────────────────────────────
mock-exam-1:
	./mock-exams/mock-exam-1/run-exam.sh

mock-exam-2:
	./mock-exams/mock-exam-2/run-exam.sh

mock-exam-3:
	./mock-exams/mock-exam-3/run-exam.sh

# ── Quality ────────────────────────────────────────────────────────────────────
bash-syntax-check:
	@fail=0; \
	for f in $$(find . -name '*.sh' -not -path './.git/*'); do \
		bash -n "$$f" || fail=1; \
	done; \
	if [ $$fail -eq 0 ]; then echo "All shell scripts passed bash -n"; else exit 1; fi

shellcheck-all:
	@if ! command -v shellcheck >/dev/null; then echo "shellcheck not installed — skipping"; exit 0; fi
	@fail=0; \
	for f in $$(find . -name '*.sh' -not -path './.git/*'); do \
		shellcheck "$$f" || fail=1; \
	done; \
	if [ $$fail -eq 0 ]; then echo "shellcheck: no issues"; else exit 1; fi
