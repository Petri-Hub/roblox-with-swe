.PHONY: build build-staging build-production test-on-system test-on-rocale format-apply format-check lint serve

format-apply:
	stylua src tests

format-check:
	stylua src tests --check

lint:
	selene src tests

build:
	rojo build --output ./dist/development.rbxlx

build-staging:
	rojo build --output ./dist/staging.rbxlx

build-production:
	rojo build --output ./dist/production.rbxlx

test-on-system:
	jest-roblox-cli

test-on-rocale:
	@echo "Open Cloud tests are not configured yet." >&2; exit 1

serve:
	rojo serve
