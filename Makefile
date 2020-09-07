RUNNER ?= docker-compose run --rm -T

init: pull-required-images
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

demo:
	@echo "\e[32mCreating new customer...\e[0m \n"
	@$(MAKE) create_customer FIRST_NAME="Linus" LAST_NAME="Torvalds" EMAIL="fake@mail.com"  
	@echo "\n \e[32mListing table content\e[0m \n"
	@$(MAKE) list_customers
.PHONY: demo

create_customer: pull-required-images
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

list_customers: pull-required-images
	@$(RUNNER) aws dynamodb scan \
		--table-name DA_Serverless \
		--output json \
		| $(RUNNER) jq '[.Items[] | {id: .id.S, firstname: .firstname.S, lastname: .lastname.S, email: .email.S, created_at: .created_time.S}]' 
.PHONY:list_customers

pull-required-images:
	@if [ -z "$(shell docker image ls --filter=reference=stedolan/jq -q)" ]; then\
		docker-compose pull jq;\
	fi

	@if [ -z "$(shell docker image ls --filter=reference=hashicorp/terraform -q)" ]; then\
		docker-compose pull terraform;\
	fi

	@if [ -z "$(shell docker image ls --filter=reference=flemay/musketeers -q)" ]; then\
		docker-compose pull toolbox;\
	fi

	@if [ -z "$(shell docker image ls --filter=reference=amazon/aws-cli -q)" ]; then\
		docker-compose pull aws;\
	fi
.PHONY:pull-required-images