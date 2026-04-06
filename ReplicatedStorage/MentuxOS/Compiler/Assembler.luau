local ExecutableFormat = require(script.Parent.Parent:WaitForChild("ExecutableFormat"))
local InstructionSet = require(script.Parent.Parent:WaitForChild("InstructionSet"))
local Util = require(script.Parent.Parent:WaitForChild("Util"))

local Assembler = {}

local function unquote(text)
	local quote = text:sub(1, 1)
	local body = text:sub(2, -2)
	body = body:gsub("\\n", "\n")
	body = body:gsub('\\"', '"')
	body = body:gsub("\\\\", "\\")
	if quote == "'" then
		body = body:gsub("\\'", "'")
	end
	return body
end

local function splitOperands(text)
	local operands = {}
	local current = {}
	local quote = nil
	local escape = false

	for index = 1, #text do
		local character = text:sub(index, index)

		if escape then
			table.insert(current, character)
			escape = false
		elseif character == "\\" and quote then
			table.insert(current, character)
			escape = true
		elseif quote then
			table.insert(current, character)
			if character == quote then
				quote = nil
			end
		elseif character == '"' or character == "'" then
			table.insert(current, character)
			quote = character
		elseif character == "," then
			table.insert(operands, Util.trim(table.concat(current)))
			current = {}
		else
			table.insert(current, character)
		end
	end

	local tail = Util.trim(table.concat(current))
	if tail ~= "" then
		table.insert(operands, tail)
	end

	return operands
end

local function parseLiteral(token, state)
	token = Util.trim(token)

	if InstructionSet.isRegister(token) then
		return token
	end

	if token == "true" then
		return true
	elseif token == "false" then
		return false
	end

	if token:match("^%-?%d+%.?%d*$") then
		return tonumber(token)
	end

	if (token:sub(1, 1) == '"' and token:sub(-1) == '"') or (token:sub(1, 1) == "'" and token:sub(-1) == "'") then
		return unquote(token)
	end

	if token:sub(1, 1) == "@" then
		local name = token:sub(2)
		assert(state.constantLookup[name] ~= nil, "Unknown constant " .. name)
		return Util.deepCopy(state.constantLookup[name])
	end

	if token:sub(1, 1) == "%" then
		local name = token:sub(2)
		assert(state.dataLookup[name] ~= nil, "Unknown data symbol " .. name)
		return {
			section = "data",
			offset = state.dataLookup[name],
		}
	end

	return token
end

local function parseDirective(line, state)
	local keyword, remainder = line:match("^%.([%w_]+)%s*(.*)$")
	assert(keyword, "Invalid assembler directive: " .. line)
	keyword = string.lower(keyword)
	remainder = Util.trim(remainder)

	if keyword == "name" then
		state.name = remainder
	elseif keyword == "kind" then
		state.kind = remainder
	elseif keyword == "stack" then
		state.stackSize = tonumber(remainder)
	elseif keyword == "entry" then
		state.entryLabel = remainder
	elseif keyword == "const" then
		local symbol, literal = remainder:match("^([%a_][%w_]*)%s*=%s*(.+)$")
		assert(symbol and literal, "Invalid .const syntax")
		local value = parseLiteral(literal, state)
		state.constantLookup[symbol] = value
		table.insert(state.constantList, value)
	elseif keyword == "data" then
		local symbol, literal = remainder:match("^([%a_][%w_]*)%s*=%s*(.+)$")
		assert(symbol and literal, "Invalid .data syntax")
		state.dataLookup[symbol] = state.nextDataOffset
		table.insert(state.dataList, {
			offset = state.nextDataOffset,
			value = parseLiteral(literal, state),
		})
		state.nextDataOffset += 1
	else
		error("Unsupported assembler directive ." .. keyword)
	end
end

local function encodeInstruction(record, state)
	local opcode = string.upper(record.opcode)
	local operands = record.operands

	if opcode == "NOP" or opcode == "RET" or opcode == "HALT" then
		return InstructionSet.instruction(opcode)
	elseif opcode == "LOADK" then
		return InstructionSet.instruction(opcode, {
			a = operands[1],
			b = parseLiteral(operands[2], state),
		})
	elseif opcode == "MOV" or opcode == "LOAD" or opcode == "STORE" then
		return InstructionSet.instruction(opcode, {
			a = operands[1],
			b = parseLiteral(operands[2], state),
		})
	elseif opcode == "ADD" or opcode == "SUB" or opcode == "MUL" or opcode == "DIV" then
		return InstructionSet.instruction(opcode, {
			a = operands[1],
			b = parseLiteral(operands[2], state),
			c = parseLiteral(operands[3], state),
		})
	elseif opcode == "CMP" then
		return InstructionSet.instruction(opcode, {
			a = parseLiteral(operands[1], state),
			b = parseLiteral(operands[2], state),
		})
	elseif opcode == "JMP" or opcode == "CALL" then
		local target = operands[1]
		assert(state.labels[target] ~= nil, "Unknown label " .. tostring(target))
		return InstructionSet.instruction(opcode, {
			target = state.labels[target],
		})
	elseif opcode == "JMPIF" then
		local target = operands[2]
		assert(state.labels[target] ~= nil, "Unknown label " .. tostring(target))
		return InstructionSet.instruction(opcode, {
			condition = string.lower(operands[1]),
			target = state.labels[target],
		})
	elseif opcode == "PUSH" or opcode == "POP" then
		return InstructionSet.instruction(opcode, {
			a = parseLiteral(operands[1], state),
		})
	elseif opcode == "SYSCALL" then
		local left, right = record.raw:match("^(.-)%s*=>%s*(.-)$")
		local syscallOperands = splitOperands(left or record.raw)
		local name = parseLiteral(syscallOperands[1], state)
		local args = {}

		for index = 2, #syscallOperands do
			table.insert(args, parseLiteral(syscallOperands[index], state))
		end

		return InstructionSet.instruction(opcode, {
			name = name,
			args = args,
			ret = right and Util.trim(right) ~= "" and Util.trim(right) or nil,
		})
	end

	error("Unsupported opcode " .. opcode)
end

function Assembler.assemble(spec)
	assert(type(spec) == "table", "Assembler spec must be a table")
	assert(type(spec.source) == "string", "Assembler source must be a string")

	local state = {
		name = spec.name or "unnamed",
		kind = spec.kind or "program",
		stackSize = spec.stackSize or 128,
		entryLabel = spec.entryLabel,
		labels = {},
		instructionRecords = {},
		constantLookup = {},
		constantList = {},
		dataLookup = {},
		dataList = {},
		nextDataOffset = 0,
	}

	for lineNumber, rawLine in ipairs(string.split(spec.source, "\n")) do
		local line = Util.trim(rawLine:gsub(";.*$", ""))
		if line ~= "" then
			while true do
				local label, remainder = line:match("^([%a_][%w_]*):%s*(.*)$")
				if not label then
					break
				end

				state.labels[label] = #state.instructionRecords
				line = Util.trim(remainder)
				if line == "" then
					break
				end
			end

			if line ~= "" then
				if line:sub(1, 1) == "." then
					parseDirective(line, state)
				else
					local opcode, remainder = line:match("^([%a_][%w_]*)%s*(.*)$")
					assert(opcode, string.format("Assembler parse error on line %d: %s", lineNumber, rawLine))
					table.insert(state.instructionRecords, {
						opcode = opcode,
						operands = splitOperands(remainder),
						raw = remainder,
					})
				end
			end
		end
	end

	local code = {}
	for _, record in ipairs(state.instructionRecords) do
		table.insert(code, encodeInstruction(record, state))
	end

	local entryPoint = 0
	if state.entryLabel then
		assert(state.labels[state.entryLabel] ~= nil, "Unknown entry label " .. state.entryLabel)
		entryPoint = state.labels[state.entryLabel]
	elseif state.labels.start ~= nil then
		entryPoint = state.labels.start
	end

	return ExecutableFormat.new({
		name = state.name,
		kind = state.kind,
		stackSize = state.stackSize,
		entryPoint = entryPoint,
		code = code,
		constants = state.constantList,
		data = state.dataList,
	})
end

return Assembler
