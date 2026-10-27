#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=$(sed -nE 's/^[[:space:]]*jest-roblox-cli[[:space:]]*=[[:space:]]*"christopher-buss\/jest-roblox-cli@([^"]+)".*$/\1/p' "$project_root/rokit.toml")

if [[ -z $version ]]; then
	echo 'Could not find the jest-roblox-cli version in rokit.toml.' >&2
	exit 1
fi

version=${version#v}
wine_user_dir="$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/$(id -un)"

if [[ ! -d $wine_user_dir ]]; then
	echo 'Vinegar Studio is not set up for this user. Start Vinegar once, then try again.' >&2
	exit 1
fi

plugins_dir="$wine_user_dir/AppData/Local/Roblox/Plugins"
mkdir -p -- "$plugins_dir"

download_path=$(mktemp "$plugins_dir/.JestRobloxRunner.XXXXXX")
cleanup() {
	if [[ -e $download_path ]]; then
		unlink -- "$download_path"
	fi
}
trap cleanup EXIT

plugin_url="https://github.com/christopher-buss/jest-roblox-cli/releases/download/v${version}/JestRobloxRunner.rbxm"
curl --fail --location --silent --show-error --retry 3 --output "$download_path" "$plugin_url"
chmod 644 "$download_path"
mv -- "$download_path" "$plugins_dir/JestRobloxRunner.rbxm"

printf 'Installed Jest Studio plugin v%s. Restart Studio before running tests.\n' "$version"
