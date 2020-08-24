RUNNER ?= docker-compose run --rm -e "TERM=xterm-256color"

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
	@rm -f ./terraform/lambda.zip
.PHONY: clean

pack_lambda:
	@$(RUNNER) toolbox make _pack_lambda
.PHONY:pack_lambda

_pack_lambda:
	@cd ./src && zip lambda.zip main.py
	@mv ./src/lambda.zip ./terraform/lambda.zip
.PHONY:_pack_lambda

create_customer:
	@$(eval API_KEY=$(shell $(RUNNER) jq -r ".outputs[\"api_key\"].value" ./terraform/terraform.tfstate))
	@$(eval API_URL=$(shell $(RUNNER) jq -r ".outputs[\"api_url\"].value" ./terraform/terraform.tfstate))

	@$(eval CURL_REQUEST="curl -v -POST \
		-H \"X-API-Key: $(API_KEY)\" \
		-H \"Content-type: application/json\" \
		--url \"$(API_URL)/customers\" \
		-d \'{ \"firstname\": \"$(FIRST_NAME)\", \"lastname\": \"$(LAST_NAME)\", \"email\": \"$(EMAIL)\" }\'")

	@echo "Running cURL command: $(CURL_REQUEST)"

	@$(shell echo "$(CURL_REQUEST)")
.PHONY:create_customer


list_customers:
	@aws dynamodb scan \
		--table-name DA_Serverless \
		--output json \
		| jq '[.Items[] | {id: .id.S, firstname: .firstname.S, lastname: .lastname.S, email: .email.S, created_at: .created_time.S}]' 
.PHONY:list_customers