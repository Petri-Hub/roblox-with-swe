#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_log="$project_root/dist/studio-test-output.log"
launcher_log="$project_root/dist/studio-test-launcher.log"

wine_path() {
	local absolute_path
	absolute_path=$(realpath "$1")
	printf 'Z:%s' "${absolute_path//\//\\}"
}

: > "$output_log"

if ! timeout 120s flatpak run org.vinegarhq.Vinegar \
	--task RunScript \
	--localPlaceFile "$(wine_path "$project_root/dist/tests.rbxlx")" \
	--runScriptFile "$(wine_path "$project_root/tests/RunTests.cli.luau")" \
	--outputFile "$(wine_path "$output_log")" \
	--quitAfterExecution > "$launcher_log" 2>&1; then
	echo "Studio did not complete the test run. See $launcher_log" >&2
	exit 1
fi

if ! grep -q 'JEST_TESTS_PASSED' "$output_log"; then
	grep -E ' FAIL |Test Suites:|Tests:' "$output_log" | tail -n 20 >&2 || true
	echo "Jest did not pass. See $output_log" >&2
	exit 1
fi

grep -E ' PASS |Test Suites:|Tests:' "$output_log"
