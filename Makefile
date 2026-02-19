.PHONY: build test test-race lint clean install help build-notifier

# Binary names
BINARY=claude-notifications
SOUND_PREVIEW=sound-preview
LIST_SOUNDS=list-sounds
BINARY_PATH=bin/$(BINARY)
SOUND_PREVIEW_PATH=bin/$(SOUND_PREVIEW)
LIST_SOUNDS_PATH=bin/$(LIST_SOUNDS)

# Build flags
# Development build: includes debug symbols for debugging
# Production build: optimized for size and deployment
RELEASE_FLAGS=-ldflags="-s -w" -trimpath

# Build targets
build: ## Build the binaries (development mode with debug symbols)
	@echo "Building $(BINARY), $(SOUND_PREVIEW) and $(LIST_SOUNDS) (development mode)..."
	@go build -o $(BINARY_PATH) ./cmd/claude-notifications
	@go build -o $(SOUND_PREVIEW_PATH) ./cmd/sound-preview
	@go build -o $(LIST_SOUNDS_PATH) ./cmd/list-sounds
	@echo "Build complete! Binaries in bin/"

build-all: ## Build optimized binaries for all platforms
	@echo "Building optimized release binaries for all platforms..."
	@mkdir -p dist
	@echo "Building claude-notifications..."
	@GOOS=darwin GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(BINARY)-darwin-amd64 ./cmd/claude-notifications
	@GOOS=darwin GOARCH=arm64 go build $(RELEASE_FLAGS) -o dist/$(BINARY)-darwin-arm64 ./cmd/claude-notifications
	@GOOS=linux GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(BINARY)-linux-amd64 ./cmd/claude-notifications
	@GOOS=linux GOARCH=arm64 go build $(RELEASE_FLAGS) -o dist/$(BINARY)-linux-arm64 ./cmd/claude-notifications
	@GOOS=windows GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(BINARY)-windows-amd64.exe ./cmd/claude-notifications
	@echo "Building sound-preview..."
	@GOOS=darwin GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(SOUND_PREVIEW)-darwin-amd64 ./cmd/sound-preview
	@GOOS=darwin GOARCH=arm64 go build $(RELEASE_FLAGS) -o dist/$(SOUND_PREVIEW)-darwin-arm64 ./cmd/sound-preview
	@GOOS=linux GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(SOUND_PREVIEW)-linux-amd64 ./cmd/sound-preview
	@GOOS=linux GOARCH=arm64 go build $(RELEASE_FLAGS) -o dist/$(SOUND_PREVIEW)-linux-arm64 ./cmd/sound-preview
	@GOOS=windows GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(SOUND_PREVIEW)-windows-amd64.exe ./cmd/sound-preview
	@echo "Building list-sounds..."
	@GOOS=darwin GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(LIST_SOUNDS)-darwin-amd64 ./cmd/list-sounds
	@GOOS=darwin GOARCH=arm64 go build $(RELEASE_FLAGS) -o dist/$(LIST_SOUNDS)-darwin-arm64 ./cmd/list-sounds
	@GOOS=linux GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(LIST_SOUNDS)-linux-amd64 ./cmd/list-sounds
	@GOOS=linux GOARCH=arm64 go build $(RELEASE_FLAGS) -o dist/$(LIST_SOUNDS)-linux-arm64 ./cmd/list-sounds
	@GOOS=windows GOARCH=amd64 go build $(RELEASE_FLAGS) -o dist/$(LIST_SOUNDS)-windows-amd64.exe ./cmd/list-sounds
	@echo "Build complete! Optimized binaries in dist/"

# Test targets
test: ## Run tests
	@echo "Running tests..."
	@go test -v -cover ./...

test-race: ## Run tests with race detection
	@echo "Running tests with race detection..."
	@go test -v -race -cover ./...

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=coverage.txt -covermode=atomic ./...
	@go tool cover -html=coverage.txt -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Linting
lint: ## Run linter
	@echo "Running linter..."
	@go vet ./...
	@go fmt ./...

# Installation
install: build ## Install binary to /usr/local/bin
	@echo "Installing $(BINARY) to /usr/local/bin..."
	@cp $(BINARY_PATH) /usr/local/bin/$(BINARY)
	@echo "Installation complete!"

# Cleanup
clean: ## Clean build artifacts
	@echo "Cleaning..."
	@rm -rf bin/ dist/ coverage.* *.log
	@echo "Clean complete!"

# Rebuild and prepare for commit
rebuild-and-commit: build-all ## Rebuild optimized binaries and prepare for commit
	@echo "Moving optimized binaries to bin/..."
	@cp dist/* bin/ 2>/dev/null || true
	@rm -rf dist
	@echo "✓ Optimized binaries ready in bin/"
	@echo ""
	@echo "Platform binaries updated:"
	@ls -1 bin/claude-notifications-* 2>/dev/null || echo "  (none found)"
	@echo ""
	@echo "To commit: git add bin/claude-notifications-* && git commit -m 'chore: rebuild binaries'"

# Swift notifier (macOS only)
build-notifier: ## Build ClaudeNotifier .app bundle (macOS)
	@echo "Building ClaudeNotifier..."
	@cd swift-notifier && bash scripts/build-app.sh
	@echo "Done! Bundle at swift-notifier/ClaudeNotifier.app"

# Help
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
