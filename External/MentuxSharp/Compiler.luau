local FrontEnd = require(script.Parent:WaitForChild("FrontEnd"))
local Lowerer = require(script.Parent:WaitForChild("Lowerer"))
local CodeGen = require(script.Parent:WaitForChild("CodeGen"))
local ImageEmitter = require(script.Parent:WaitForChild("ImageEmitter"))

local Compiler = {}

function Compiler.compile(source, options)
	options = options or {}

	local frontEnd = FrontEnd.parseDetailed(source)
	local ir = Lowerer.lower(frontEnd.ast, options)
	local backend = CodeGen.generate(ir, options)
	local emitted = ImageEmitter.emit(ir, options)

	return {
		tokens = frontEnd.tokens,
		ast = frontEnd.ast,
		ir = ir,
		backend = backend,
		image = emitted.image,
		imageWarnings = emitted.warnings,
	}
end

function Compiler.tryCompile(source, options)
	local ok, result = pcall(function()
		return Compiler.compile(source, options)
	end)

	if ok then
		result.ok = true
		return result
	end

	return {
		ok = false,
		error = result,
	}
end

function Compiler.compileImage(source, options)
	return Compiler.compile(source, options).image
end

return Compiler
