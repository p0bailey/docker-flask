# Docker Flask Application Makefile
IMAGE_NAME = docker-flask
CONTAINER_NAME = flask-app
PORT = 8080

.DEFAULT_GOAL := help

# Quickstart
.PHONY: run
run: clean build ## Build and run standalone container
	docker run -d --name $(CONTAINER_NAME) -p $(PORT):8080 $(IMAGE_NAME)

# Build targets
.PHONY: build
build: ## Build Docker image
	docker build -t $(IMAGE_NAME) .

.PHONY: build-no-cache
build-no-cache: ## Build Docker image without cache
	docker build --no-cache -t $(IMAGE_NAME) .

# Run targets
.PHONY: up
up: ## Start services using docker-compose
	docker-compose up -d

.PHONY: up-build
up-build: ## Start services and rebuild
	docker-compose up -d --build

.PHONY: down
down: ## Stop and remove containers
	docker-compose down

.PHONY: dev
dev: ## Start development environment
	docker-compose up --build

# Testing targets
.PHONY: test
test: ## Run tests inside container
	docker run --rm $(IMAGE_NAME) python3 /var/www/app/test.py

.PHONY: test-compose
test-compose: ## Run tests using docker-compose
	docker-compose exec nginx python3 /var/www/app/test.py

.PHONY: test-local
test-local: ## Run tests locally
	cd app && python3 test.py

# Development tools
.PHONY: shell
shell: ## Access container shell
	docker exec -it $(CONTAINER_NAME) /bin/bash

.PHONY: logs
logs: ## Show container logs
	docker logs -f $(CONTAINER_NAME)

.PHONY: logs-compose
logs-compose: ## Show docker-compose logs
	docker-compose logs -f

# Security scanning
.PHONY: scan
scan: build ## Scan image for vulnerabilities
	@mkdir -p reports
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace aquasec/trivy:latest image \
		--format table $(IMAGE_NAME)

.PHONY: scan-json
scan-json: build ## Generate JSON security reports
	@mkdir -p reports
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace aquasec/trivy:latest image \
		--format json --output /workspace/reports/image-scan.json $(IMAGE_NAME)

# Cleanup targets
.PHONY: stop
stop: ## Stop container
	docker stop $(CONTAINER_NAME) || true

.PHONY: clean
clean: stop ## Remove container and image
	docker rm $(CONTAINER_NAME) || true
	docker rmi $(IMAGE_NAME) || true

.PHONY: clean-all
clean-all: ## Remove all unused containers and images
	docker system prune -af

# Utility targets
.PHONY: restart
restart: stop run ## Restart container

.PHONY: status
status: ## Show container status
	docker ps -f name=$(CONTAINER_NAME)

# Help target
.PHONY: help
help: ## Show this help message
	@echo "Docker Flask Application Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME     = $(IMAGE_NAME)"
	@echo "  CONTAINER_NAME = $(CONTAINER_NAME)"
	@echo "  PORT          = $(PORT)"