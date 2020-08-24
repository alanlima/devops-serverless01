RUNNER ?= docker-compose run --rm

init: 
	@$(RUNNER) terraform init
.PHONY:init

apply: 
	@$(RUNNER) terraform apply
.PHONY: apply

deploy: init pack_lambda
	@$(RUNNER) terraform apply -auto-approve
.PHONY: deploy

clean:
	@$(RUNNER) terraform destroy -auto-approve
.PHONY: clean

pack_lambda:
	@$(RUNNER) toolbox make _pack_lambda
.PHONY:pack_lambda

_pack_lambda:
	@cd ./src && zip lambda.zip main.py
	@mv ./src/lambda.zip ./terraform/lambda.zip
.PHONY:_pack_lambda