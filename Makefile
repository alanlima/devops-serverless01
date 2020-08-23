RUNNER ?= docker-compose run --rm

init: 
	@$(RUNNER) terraform init
.PHONY:init

apply: 
	@$(RUNNER) terraform apply
.PHONY: apply

deploy: init
	@$(RUNNER) terraform apply -auto-approve
.PHONY: deploy

clean:
	@$(RUNNER) terraform destroy -auto-approve
.PHONY: clean