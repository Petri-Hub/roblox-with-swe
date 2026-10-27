#!/usr/bin/env bash
set -euo pipefail

wine_path() {
	local absolute_path
	absolute_path=$(realpath -m -- "$1")
	printf 'Z:%s' "${absolute_path//\//\\}"
}

studio_args=()
while (($#)); do
	case "$1" in
		--localPlaceFile|--runScriptFile|--outputFile)
			studio_args+=("$1" "$(wine_path "$2")")
			shift 2
			;;
		*)
			studio_args+=("$1")
			shift
			;;
	esac
done

exec flatpak run org.vinegarhq.Vinegar "${studio_args[@]}"
