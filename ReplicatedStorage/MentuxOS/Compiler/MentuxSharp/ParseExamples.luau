local FrontEnd = require(script.Parent:WaitForChild("FrontEnd"))
local SourceLoader = require(script.Parent:WaitForChild("SourceLoader"))

local ParseExamples = {}

function ParseExamples.loadSamples()
	return SourceLoader.loadSamples()
end

function ParseExamples.run()
	local results = {}
	local samples = ParseExamples.loadSamples()

	for name, source in pairs(samples) do
		local parsed = FrontEnd.tryParse(source)
		results[name] = {
			ok = parsed.ok,
			error = parsed.error,
			tokenCount = parsed.tokens and #parsed.tokens or 0,
			rootKind = parsed.ast and parsed.ast.kind or nil,
		}
	end

	return results
end

return ParseExamples
