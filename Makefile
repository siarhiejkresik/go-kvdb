.DEFAULT_GOAL := build

DEV := dev
PROD := prod
TAG := latest

BIN := bin
SRC := src

APP_BASE_NAME := go-kvdb
APP_CLIENT_NAME := client
APP_SERVER_NAME := server

REPOSITORY_PATH := github.com/siarhiejkresik

DEV_GOPATH := /go
DEV_GOPATH_BIN := $(DEV_GOPATH)/$(BIN)
DEV_GOPATH_SRC := $(DEV_GOPATH)/$(SRC)
DEV_WORKDIR := $(DEV_GOPATH_SRC)/$(REPOSITORY_PATH)/$(APP_BASE_NAME)

SRC_MOUNT := "$(PWD):$(DEV_GOPATH_SRC)/$(REPOSITORY_PATH)/$(APP_BASE_NAME)"
BIN_MOUNT := "$(PWD)/$(BIN):$(DEV_GOPATH_BIN)"

DEV_IMAGE := $(APP_BASE_NAME)-${DEV}
PROD_IMAGE := $(APP_BASE_NAME)

BUILDER := docker build
RUNNER := docker run --rm
CHECKER := $(RUNNER) -v $(SRC_MOUNT) -w $(DEV_WORKDIR) $(DEV_IMAGE)

COVERAGE := coverage.out

SEARCH_GOFILES = find -not -path '*/vendor/*' -type f -name "*.go"

DELIMITER="----------------------"
define print_target_name
	@echo $(DELIMITER)
	@echo $(1)
	@echo $(DELIMITER)
endef

### targets ###

build: build-dev-image build-dev build-prod-image clean

build-dev-image:
	$(call print_target_name, "Building an image with go tools for development...")
	$(BUILDER) -t $(DEV_IMAGE) --target $(DEV) .

build-dev:
	$(call print_target_name, "Compile binaries...")
	@mkdir $(BIN)
	$(RUNNER) -v $(BIN_MOUNT) -v $(SRC_MOUNT) -w $(DEV_WORKDIR) $(DEV_IMAGE) sh -c "go install ./..."

build-prod-image:
	$(call print_target_name, "Building an image with server and client binaries")
	$(BUILDER) -t $(PROD_IMAGE) --target $(PROD) .

test: test-ut coverage

test-ut:
	$(call print_target_name, "Run unit tests...")
	@$(CHECKER) sh -c 'CGO_ENABLED="0" go test ./...'

coverage:
	$(call print_target_name, "Measure test coverage...")
	@$(CHECKER) sh -c '\
		CGO_ENABLED="0" go test ./... -coverprofile=/dev/null | tee $(COVERAGE) \
		&& chmod 666 $(COVERAGE)'

check: build-dev-image check-goimports check-golint check-govet

check-govet:
	$(call print_target_name, "Checks (go vet)...")
	@$(CHECKER) sh -c 'go tool vet -v . | grep -v "Checking file"'

check-goimports:
	$(call print_target_name, "Checks (goimports)...")
	@$(CHECKER) sh -c 'test -z "`goimports -e -d .`"'

check-golint:
	$(call print_target_name, "Checks (golint)...")
	@$(CHECKER) sh -c 'test -z "`golint ./...`"'

check-golint-verbose:
	$(call print_target_name, "Checks (golint)...")
	@$(CHECKER) sh -c 'golint ./...'

run: run-server

run-server:
	$(call print_target_name, "Run server...")
	$(RUNNER) -p 9090:9090 $(APP_BASE_NAME):$(TAG) $(ARGS)

run-client:
	$(call print_target_name, "Run client...")
	$(RUNNER) -it --entrypoint /app/client $(APP_BASE_NAME):$(TAG) $(ARGS)

run-dev:
	$(RUNNER) -it -v $(SRC_MOUNT) -w $(DEV_WORKDIR) $(DEV_IMAGE) sh

clean:
	$(call print_target_name, "Cleaning...")
	@rm -rf ./$(BIN)/
	@rm -f $(COVERAGE) \

prune:
	docker image prune
