# One entry point for humans and CI, so both run exactly the same commands.
#
#   make plan  ENV=prod-us-west-2                   read-only plan (default role)
#   make plan  ENV=dev ROLE=terraform-apply         plan with the apply role
#   make apply ENV=dev                              apply the plan saved by `make plan`
#
# `make` cannot pass terraform's -detailed-exitcode through: any failing recipe
# makes `make` itself exit 2, so "error" and "changes present" would look the
# same. `plan` therefore exits 0 when terraform planned successfully (with or
# without changes) and non-zero on any error, and records terraform's own code
# (0 = no changes, 2 = changes) in .plans/<env>.exitcode for callers that need it.

ENVS      := dev staging prod-us-east-1 prod-us-west-2 prod-eu-central-1
ROLE      ?= terraform-plan
PLAN_DIR  := .plans
PLAN_FILE := $(PLAN_DIR)/$(ENV).tfplan
CODE_FILE := $(PLAN_DIR)/$(ENV).exitcode
TF        ?= terraform

.PHONY: help check-env init validate fmt plan apply validate-all

help:
	@echo "targets: init plan apply validate fmt validate-all   (set ENV=<one of: $(ENVS)>)"

check-env:
	@test -n "$(ENV)" || { echo "ENV is required, one of: $(ENVS)"; exit 1; }
	@test -f backend/$(ENV).hcl || { echo "missing backend/$(ENV).hcl"; exit 1; }
	@test -f env/$(ENV).tfvars  || { echo "missing env/$(ENV).tfvars"; exit 1; }

# -reconfigure lets one working directory switch between environments safely.
init: check-env
	$(TF) init -input=false -reconfigure -backend-config=backend/$(ENV).hcl

plan: init
	@mkdir -p $(PLAN_DIR)
	@rm -f $(PLAN_FILE) $(CODE_FILE)
	@$(TF) plan -input=false -lock-timeout=5m -detailed-exitcode \
		-var-file=env/$(ENV).tfvars -var target_role_name=$(ROLE) -out=$(PLAN_FILE); \
	code=$$?; \
	case $$code in \
		0) echo 0 > $(CODE_FILE); echo "plan $(ENV): no changes" ;; \
		2) echo 2 > $(CODE_FILE); echo "plan $(ENV): changes present" ;; \
		*) echo "plan $(ENV): terraform plan FAILED (exit $$code)" >&2; exit 1 ;; \
	esac

# Applies exactly the saved plan, never a fresh one. The role used is the one
# the plan was made with, so produce it with ROLE=terraform-apply.
apply: check-env
	@test -f $(PLAN_FILE) || { echo "no saved plan; run: make plan ENV=$(ENV) ROLE=terraform-apply"; exit 1; }
	@test "$$(cat $(CODE_FILE) 2>/dev/null)" = 2 || { echo "saved plan has no changes or did not succeed; nothing to apply"; exit 1; }
	$(TF) apply -input=false -lock-timeout=5m $(PLAN_FILE)

fmt:
	$(TF) fmt -recursive

# No credentials or backend needed.
validate:
	$(TF) init -backend=false -input=false
	$(TF) validate

validate-all: validate
	@for d in modules/*/ bootstrap bootstrap/target-account; do \
		echo "== $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null && \
		$(TF) -chdir=$$d validate || exit 1; \
	done
