.PHONY: build build-staging build-production format-apply format-check serve

build:
	rojo build --output ./dist/development.rbxlx

build-staging:
	rojo build --output ./dist/staging.rbxlx

build-production:
	rojo build --output ./dist/production.rbxlx

format-apply:
	stylua src

format-check:
	stylua src --check

serve:
	rojo serve
