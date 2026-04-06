local ParseExamples = require(script.Parent:WaitForChild("ParseExamples"))
local Compiler = require(script.Parent:WaitForChild("Compiler"))
local CodeGen = require(script.Parent:WaitForChild("CodeGen"))
local ImageEmitter = require(script.Parent:WaitForChild("ImageEmitter"))

local ExampleRenderer = {}

local function stringify(value, depth)
	depth = depth or 0
	local indent = string.rep("  ", depth)

	if type(value) ~= "table" then
		if type(value) == "string" then
			return string.format("%q", value)
		end
		return tostring(value)
	end

	local isArray = (#value > 0)
	local lines = {}
	if isArray then
		table.insert(lines, "[")
		for _, item in ipairs(value) do
			table.insert(lines, indent .. "  " .. stringify(item, depth + 1) .. ",")
		end
		table.insert(lines, indent .. "]")
	else
		table.insert(lines, "{")
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, key)
		end
		table.sort(keys, function(left, right)
			return tostring(left) < tostring(right)
		end)
		for _, key in ipairs(keys) do
			table.insert(lines, indent .. "  " .. tostring(key) .. " = " .. stringify(value[key], depth + 1) .. ",")
		end
		table.insert(lines, indent .. "}")
	end

	return table.concat(lines, "\n")
end

function ExampleRenderer.renderOne(name, source)
	local compiled = Compiler.compile(source, {
		name = name,
	})

	return table.concat({
		"=== " .. name .. " ===",
		"-- Source --",
		source,
		"",
		"-- IR --",
		stringify(compiled.ir),
		"",
		"-- Backend --",
		CodeGen.renderListing(compiled.backend),
		"",
		"-- Image --",
		ImageEmitter.describe(compiled.image),
		"",
	}, "\n")
end

function ExampleRenderer.renderAll()
	local outputs = {}
	local samples = ParseExamples.loadSamples()
	local names = {}
	for name in pairs(samples) do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in ipairs(names) do
		table.insert(outputs, ExampleRenderer.renderOne(name, samples[name]))
	end

	return table.concat(outputs, "\n")
end

return ExampleRenderer
