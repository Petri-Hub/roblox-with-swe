local root = script.Parent
local Jest = require(root.DevPackages.Jest)

local status, result = Jest.runCLI(root, {
	verbose = true,
	ci = false,
}, { root }):awaitStatus()

if status == "Rejected" then
	error(result)
end

if not result.results.success then
	error("Tests failed")
end
