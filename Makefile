.PHONY: build build-staging build-production test-on-system test-on-ocale format-apply format-check lint serve

-include .env

export ROBLOX_OPEN_CLOUD_API_KEY
export ROBLOX_UNIVERSE_ID
export ROBLOX_PLACE_ID

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
	jest-roblox-cli --backend studio-cli

test-on-ocale:
	jest-roblox-cli --backend open-cloud

serve:
	rojo serve
