# Docker Flask Application Makefile
# Variables
IMAGE_NAME = docker-flask
CONTAINER_NAME = flask-app
COMPOSE_FILE = docker-compose.yml
PORT = 8080

# Security Configuration
# Set to 'true' to enable security scanning and /security endpoint
# Set to 'false' to disable security features for faster deployment
ENABLE_SECURITY ?= true

# Default target
.DEFAULT_GOAL := help

# Build targets
.PHONY: build
build: ## Build Docker image
	docker build -t $(IMAGE_NAME) .

.PHONY: build-no-cache
build-no-cache: ## Build Docker image without cache
	docker build --no-cache -t $(IMAGE_NAME) .

# Run targets
.PHONY: run
run: rm ## Build and run container (with optional security scanning)
ifeq ($(ENABLE_SECURITY),true)
	@echo "Starting deployment with security scanning enabled..."
	$(MAKE) trivy-pull build scan-json
	@echo "Starting container with security reports..."
	docker run -d --name $(CONTAINER_NAME) -p $(PORT):8080 $(IMAGE_NAME)
	@echo "Updating security reports in running container..."
	@sleep 3
	$(MAKE) update-security-reports
	@echo "Generating markdown security report..."
	$(MAKE) scan-markdown
	@echo "Container started successfully with latest security reports!"
	@echo "Access application: http://localhost:8080"
	@echo "Security dashboard: http://localhost:8080/security"
	@echo "Markdown report: reports/security-report.md"
else
	@echo "Starting deployment without security scanning..."
	$(MAKE) build
	@echo "Starting container..."
	docker run -d --name $(CONTAINER_NAME) -p $(PORT):8080 $(IMAGE_NAME)
	@echo "Generating markdown security report..."
	$(MAKE) scan-markdown
	@echo "Container started successfully!"
	@echo "Access application: http://localhost:8080"
	@echo "Note: Security scanning disabled. Set ENABLE_SECURITY=true to enable."
	@echo "Markdown report: reports/security-report.md"
endif

.PHONY: run-secure
run-secure: rm ## Build and run container with security scanning (always enabled)
	@echo "Starting secure deployment with security scanning..."
	$(MAKE) trivy-pull build scan-json
	@echo "Starting container with security reports..."
	docker run -d --name $(CONTAINER_NAME) -p $(PORT):8080 $(IMAGE_NAME)
	@echo "Updating security reports in running container..."
	@sleep 3
	$(MAKE) update-security-reports
	@echo "Container started successfully with latest security reports!"
	@echo "Access application: http://localhost:8080"
	@echo "Security dashboard: http://localhost:8080/security"

.PHONY: run-basic
run-basic: rm ## Build and run container without security scanning (fast deployment)
	@echo "Starting basic deployment without security scanning..."
	$(MAKE) build
	@echo "Starting container..."
	docker run -d --name $(CONTAINER_NAME) -p $(PORT):8080 $(IMAGE_NAME)
	@echo "Container started successfully!"
	@echo "Access application: http://localhost:8080"

.PHONY: run-fg
run-fg: ## Run container in foreground
	docker run --rm --name $(CONTAINER_NAME) -p $(PORT):8080 $(IMAGE_NAME)

.PHONY: up
up: ## Start services using docker-compose
	docker-compose -f $(COMPOSE_FILE) up -d

.PHONY: up-build
up-build: ## Start services and rebuild if needed
	docker-compose -f $(COMPOSE_FILE) up -d --build

.PHONY: down
down: ## Stop and remove containers
	docker-compose -f $(COMPOSE_FILE) down

# Development targets
.PHONY: dev
dev: ## Start development environment
	docker-compose -f $(COMPOSE_FILE) up --build

.PHONY: shell
shell: ## Access running container shell
	docker exec -it $(CONTAINER_NAME) /bin/bash

.PHONY: logs
logs: ## Show container logs
	docker logs -f $(CONTAINER_NAME)

.PHONY: logs-compose
logs-compose: ## Show docker-compose logs
	docker-compose -f $(COMPOSE_FILE) logs -f

# Testing targets
.PHONY: test
test: ## Run tests inside container
	docker run --rm $(IMAGE_NAME) python3 -m pytest /var/www/app/test.py

.PHONY: test-local
test-local: ## Run tests locally (requires Python 3)
	cd app && python3 test.py

.PHONY: lint
lint: ## Run linting inside container
	docker run --rm $(IMAGE_NAME) python3 -m flake8 /var/www/app/

# Health and status targets
.PHONY: health
health: ## Check container health status
	docker inspect --format='{{.State.Health.Status}}' $(CONTAINER_NAME)

.PHONY: status
status: ## Show container status
	docker ps -f name=$(CONTAINER_NAME)

.PHONY: inspect
inspect: ## Inspect container details
	docker inspect $(CONTAINER_NAME)

# Cleanup targets
.PHONY: stop
stop: ## Stop running container
	docker stop $(CONTAINER_NAME) || true

.PHONY: rm
rm: stop ## Remove container
	docker rm $(CONTAINER_NAME) || true

.PHONY: clean
clean: rm ## Clean up containers and images
	docker rmi $(IMAGE_NAME) || true

.PHONY: clean-all
clean-all: ## Remove all unused containers, networks, images
	docker system prune -af

.PHONY: clean-volumes
clean-volumes: ## Remove all unused volumes
	docker volume prune -f

# Maintenance targets
.PHONY: pull
pull: ## Pull latest base image
	docker pull debian:bookworm-slim

.PHONY: size
size: ## Show image size
	docker images $(IMAGE_NAME)

.PHONY: history
history: ## Show image build history
	docker history $(IMAGE_NAME)

# Security targets with Trivy
.PHONY: trivy-pull
trivy-pull: ## Pull latest Trivy Docker image
	@echo "Pulling latest Trivy Docker image..."
	docker pull aquasec/trivy:latest

.PHONY: trivy-install
trivy-install: trivy-pull ## Pull Trivy Docker image (replaces host installation)
	@echo "Trivy Docker image ready for use"

.PHONY: scan-image
scan-image: ## Scan Docker image for vulnerabilities with Trivy
	@echo "Scanning Docker image $(IMAGE_NAME) for vulnerabilities..."
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest image \
		--exit-code 0 --severity HIGH,CRITICAL --format table $(IMAGE_NAME)

.PHONY: scan-dockerfile
scan-dockerfile: ## Scan Dockerfile for misconfigurations
	@echo "Scanning Dockerfile for misconfigurations..."
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest config \
		--exit-code 0 --severity HIGH,CRITICAL --format table /workspace

.PHONY: scan-fs
scan-fs: ## Scan filesystem/source code for vulnerabilities
	@echo "Scanning filesystem for vulnerabilities and secrets..."
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest fs \
		--exit-code 0 --severity HIGH,CRITICAL --scanners vuln,secret,misconfig --format table /workspace

.PHONY: scan-python
scan-python: ## Scan Python dependencies for vulnerabilities
	@echo "Scanning Python dependencies..."
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest fs \
		--exit-code 0 --severity HIGH,CRITICAL --scanners vuln --format table /workspace/app/

.PHONY: scan-all
scan-all: scan-dockerfile scan-fs scan-python build scan-image ## Run all security scans
	@echo "All security scans completed!"

.PHONY: scan-json
scan-json: ## Generate JSON security reports
	@mkdir -p reports
	@echo "Generating JSON security reports..."
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest image \
		--exit-code 0 --format json --output /workspace/reports/image-scan.json $(IMAGE_NAME) || true
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest config \
		--exit-code 0 --format json --output /workspace/reports/dockerfile-scan.json /workspace || true
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest fs \
		--exit-code 0 --scanners vuln,secret,misconfig --format json --output /workspace/reports/fs-scan.json /workspace || true
	@echo "Reports generated in reports/ directory"

.PHONY: scan-markdown
scan-markdown: ## Generate markdown security report (always runs regardless of ENABLE_SECURITY)
	@mkdir -p reports
	@echo "Generating formatted markdown security report..."
	$(MAKE) trivy-pull
	@echo "# Security Report" > reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "## Overview" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "- **Image**: $(IMAGE_NAME)" >> reports/security-report.md
	@echo "- **Generated**: $$(date)" >> reports/security-report.md
	@echo "- **Scanner**: Trivy (dockerized)" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "---" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "## 🐳 Docker Image Vulnerabilities" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest image \
		--exit-code 0 --format table $(IMAGE_NAME) >> reports/security-report.md || true
	@echo "" >> reports/security-report.md
	@echo "---" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "## 📋 Dockerfile Security Analysis" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest config \
		--exit-code 0 --format table /workspace >> reports/security-report.md || true
	@echo "" >> reports/security-report.md
	@echo "---" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "## 📁 Filesystem Security Analysis" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest fs \
		--exit-code 0 --scanners vuln,secret,misconfig --format table /workspace >> reports/security-report.md || true
	@echo "" >> reports/security-report.md
	@echo "---" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "## Summary" >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "This report was automatically generated as part of the security-first deployment workflow." >> reports/security-report.md
	@echo "The container now runs as non-root user (appuser) on port 8080 for enhanced security." >> reports/security-report.md
	@echo "" >> reports/security-report.md
	@echo "> Generated with [Trivy](https://trivy.dev/) security scanner" >> reports/security-report.md
	@echo "Formatted markdown security report generated: reports/security-report.md"

.PHONY: update-security-reports
update-security-reports: scan-json ## Update security reports in running container
	@echo "Copying security reports to running container..."
	docker exec $(CONTAINER_NAME) mkdir -p /var/www/app/reports || true
	docker cp reports/. $(CONTAINER_NAME):/var/www/app/reports/ || true
	@echo "Security reports updated in container"

.PHONY: scan-ci
scan-ci: ## CI-friendly scan with exit codes for failures
	@echo "Running CI security scans..."
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest image \
		--exit-code 1 --severity HIGH,CRITICAL --quiet $(IMAGE_NAME)
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest config \
		--exit-code 1 --severity HIGH,CRITICAL --quiet /workspace
	docker run --rm -v $(PWD):/workspace \
		-v trivy-cache:/root/.cache \
		aquasec/trivy:latest fs \
		--exit-code 1 --severity HIGH,CRITICAL --scanners vuln,secret,misconfig --quiet /workspace

.PHONY: scan
scan: ## Scan image for vulnerabilities (legacy compatibility)
	$(MAKE) scan-image

.PHONY: security-check
security-check: ## Run comprehensive security checks
	@echo "Running comprehensive security checks..."
	$(MAKE) scan-all
	@echo "Checking for running processes..."
	docker run --rm $(IMAGE_NAME) ps aux || true
	@echo "Checking file permissions..."
	docker run --rm $(IMAGE_NAME) ls -la /var/www/app/ || true

# Quick commands
.PHONY: restart
restart: stop run ## Restart container

.PHONY: rebuild
rebuild: clean build run ## Rebuild and run container

.PHONY: fresh
fresh: clean pull build run ## Fresh build with latest base image

# Help target
.PHONY: help
help: ## Show this help message
	@echo "Docker Flask Application Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME      = $(IMAGE_NAME)"
	@echo "  CONTAINER_NAME  = $(CONTAINER_NAME)"
	@echo "  PORT           = $(PORT)"
	@echo "  ENABLE_SECURITY = $(ENABLE_SECURITY)"
	@echo ""
	@echo "Quick Start:"
	@echo "  make run          # Run (security: $(ENABLE_SECURITY))"
	@echo "  make run-basic    # Run without security"
	@echo "  make run-secure   # Run with security"
	@echo "  make logs         # View logs"
	@echo "  make stop         # Stop container"
	@echo ""
	@echo "Security Control:"
	@echo "  Edit ENABLE_SECURITY in Makefile (currently: $(ENABLE_SECURITY))"
	@echo "  Or: make ENABLE_SECURITY=true run"