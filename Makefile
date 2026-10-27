.PHONY: build build-staging build-production test-on-system test-on-ocale format-apply format-check lint serve

-include .env

export JEST_ROBLOX_OPEN_CLOUD_API_KEY
export JEST_ROBLOX_UNIVERSE_ID
export JEST_ROBLOX_PLACE_ID

format-apply:
	stylua src tests

format-check:
	stylua src tests --check

lint:
	selene src tests

dist:
	mkdir -p dist

build: dist
	rojo build --output ./dist/development.rbxlx

build-staging: dist
	rojo build --output ./dist/staging.rbxlx

build-production: dist
	rojo build --output ./dist/production.rbxlx

test-on-system:
	jest-roblox-cli

test-on-ocale:
	jest-roblox-cli --backend open-cloud

serve:
	rojo serve
