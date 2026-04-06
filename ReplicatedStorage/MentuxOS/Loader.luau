local ExecutableFormat = require(script.Parent:WaitForChild("ExecutableFormat"))
local Util = require(script.Parent:WaitForChild("Util"))

local Loader = {}

local RELOCATED_JUMP_OPS = {
	JMP = true,
	JMPIF = true,
	CALL = true,
}

local function relocateValue(value, layout)
	if type(value) ~= "table" then
		return value
	end

	if value.section == "data" then
		return layout.dataBase + value.offset
	elseif value.section == "const" then
		return layout.constantBase + value.offset
	end

	return Util.deepCopy(value)
end

local function relocateInstruction(instruction, layout)
	local relocated = Util.deepCopy(instruction)

	for key, value in pairs(relocated) do
		if key ~= "op" then
			if type(value) == "table" and value.section then
				relocated[key] = relocateValue(value, layout)
			elseif key == "args" then
				local relocatedArgs = {}
				for index, operand in ipairs(value) do
					relocatedArgs[index] = relocateValue(operand, layout)
				end
				relocated[key] = relocatedArgs
			end
		end
	end

	if RELOCATED_JUMP_OPS[relocated.op] and type(relocated.target) == "number" and not relocated.absoluteTarget then
		relocated.target = layout.codeBase + relocated.target
		relocated.absoluteTarget = true
	end

	return relocated
end

function Loader.loadExecutable(memory, executable, options)
	options = options or {}
	ExecutableFormat.validate(executable)

	local headerBase = options.headerBase or 0
	local constantBase = options.constantBase or 16
	local dataBase = options.dataBase or (constantBase + math.max(8, #executable.constants))
	local codeBase = options.codeBase or (dataBase + math.max(16, #executable.data))
	local stackSize = executable.stackSize
	local stackBase = memory.size - stackSize

	assert(codeBase + #executable.code < stackBase, "Executable does not fit into memory")

	for index, constantValue in ipairs(executable.constants) do
		memory:write(constantBase + index - 1, Util.deepCopy(constantValue))
	end

	for _, entry in ipairs(executable.data) do
		memory:write(dataBase + entry.offset, Util.deepCopy(entry.value))
	end

	local layout = {
		headerBase = headerBase,
		constantBase = constantBase,
		dataBase = dataBase,
		codeBase = codeBase,
		stackBase = stackBase,
		stackTop = memory.size,
		stackSize = stackSize,
		entryAddress = codeBase + executable.entryPoint,
	}

	for index, instruction in ipairs(executable.code) do
		memory:write(codeBase + index - 1, relocateInstruction(instruction, layout))
	end

	return layout
end

return Loader
