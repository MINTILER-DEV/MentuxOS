local ParseExamples = require(script.Parent:WaitForChild("ParseExamples"))
local Compiler = require(script.Parent:WaitForChild("Compiler"))
local ImageEmitter = require(script.Parent:WaitForChild("ImageEmitter"))

local function formatResult(name, result)
	if result.ok then
		return string.format("[MentuxSharp] %s parsed successfully (%d tokens, root=%s)", name, result.tokenCount, tostring(result.rootKind))
	end

	return string.format("[MentuxSharp] %s failed: %s", name, tostring(result.error))
end

local function formatCompileResult(name, result)
	if result.ok then
		return string.format(
			"[MentuxSharp] %s compiled successfully (target=%s, functions=%d, entry=%s, image=%s, warnings=%d)",
			name,
			tostring(result.backend.targetKind),
			#result.backend.functions,
			tostring(result.backend.entryPoint),
			ImageEmitter.describe(result.image),
			#(result.imageWarnings or {})
		)
	end

	return string.format("[MentuxSharp] %s compile failed: %s", name, tostring(result.error))
end

print("[MentuxSharp] Running MT# parser smoke tests")

local results = ParseExamples.run()
local failed = 0

for name, result in pairs(results) do
	print(formatResult(name, result))
	if not result.ok then
		failed += 1
	end
end

print("[MentuxSharp] Running MT# compile smoke tests")

for name, source in pairs(ParseExamples.loadSamples()) do
	local compiled = Compiler.tryCompile(source, {
		name = name,
	})
	print(formatCompileResult(name, compiled))
	if not compiled.ok then
		failed += 1
	end
end

if failed > 0 then
	error(string.format("[MentuxSharp] %d smoke test(s) failed", failed))
end

print("[MentuxSharp] All parser and compile smoke tests passed")
