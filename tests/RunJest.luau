local root = script.Parent
local Jest = require(root.DevPackages.Jest)

return function()
	local status, result = Jest.runCLI(root, {
		verbose = true,
		ci = true,
	}, { root }):awaitStatus()

	if status == "Rejected" then
		error(result)
	end

	if not result.results.success then
		error("Tests failed")
	end

	print("JEST_TESTS_PASSED")
end
