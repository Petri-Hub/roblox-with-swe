.PHONY: build serve

build:
	rojo build --output ./dist/development.rbxlx

serve:
	rojo serve