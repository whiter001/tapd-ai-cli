.PHONY: build build-cross test test-integration test-coverage lint coverage clean fmt install tools sync-upstream sync-status

BINARY_NAME=tapd
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS=-ldflags "-X github.com/whiter001/tapd-ai-cli/internal/cmd.Version=$(VERSION)"

build:
	go build $(LDFLAGS) -o $(BINARY_NAME) ./cmd/tapd/

# Cross-compile. Requires GOOS and GOARCH env vars.
# Example: GOOS=linux GOARCH=arm64 make build-cross
build-cross:
	@if [ -z "$$GOOS" ] || [ -z "$$GOARCH" ]; then \
		echo "GOOS and GOARCH must be set"; exit 1; \
	fi
	@ext=""; if [ "$$GOOS" = "windows" ]; then ext=".exe"; fi; \
	go build $(LDFLAGS) -o $(BINARY_NAME)-$$GOOS-$$GOARCH$$ext ./cmd/tapd/

test:
	go test -race ./...

test-coverage:
	go test -race -coverprofile=coverage.out -covermode=atomic ./...

test-integration:
	go test ./... -v -run "TestIntegration" -count=1

lint:
	go vet ./...
	@unformatted=$$(goimports -l .); \
	if [ -n "$$unformatted" ]; then \
		echo "The following files are not formatted with goimports:"; \
		echo "$$unformatted"; \
		exit 1; \
	fi

fmt:
	gofmt -w .
	goimports -w .

coverage: test-coverage
	go tool cover -func=coverage.out

tools:
	go install golang.org/x/tools/cmd/goimports@latest

install:
	go install $(LDFLAGS) ./cmd/tapd/

# 同步上游（studyzy/tapd-ai-cli）main 分支的更新到当前分支
sync-upstream:
	git fetch upstream --prune
	git merge --no-edit upstream/main
	@# 上游新增的 .go 文件仍带旧 module path，统一改写为本仓库路径
	git ls-files '*.go' | xargs sed -i 's|github.com/studyzy/tapd-ai-cli|github.com/whiter001/tapd-ai-cli|g'
	@echo "Sync done. Run 'make test' then push."

# 查看当前分支相对上游的领先/落后提交数
sync-status:
	@git fetch upstream --prune -q
	@echo -n "behind (upstream only): "; git rev-list --left-right --count upstream/main...main | cut -f1
	@echo -n "ahead  (local only):    "; git rev-list --left-right --count upstream/main...main | cut -f2

clean:
	rm -f $(BINARY_NAME) $(BINARY_NAME)-* coverage.out
