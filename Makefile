.PHONY: build build-staging build-production test format-apply format-check lint serve

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

test:
	jest-roblox-cli

serve:
	rojo serve
