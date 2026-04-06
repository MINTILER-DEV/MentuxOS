local InstructionSet = require(script.Parent:WaitForChild("InstructionSet"))

local CPU = {}
CPU.__index = CPU

local function formatValue(value)
	if type(value) == "table" then
		local parts = {}
		for key, nestedValue in pairs(value) do
			table.insert(parts, tostring(key) .. "=" .. tostring(nestedValue))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end

	return tostring(value)
end

function CPU.new(options)
	assert(options and options.memory, "CPU requires a memory device")

	local self = setmetatable({}, CPU)
	self.memory = options.memory
	self.trace = options.trace == true
	self.logger = options.logger or function() end
	self.onSyscall = options.onSyscall or function()
		return nil
	end
	self.registers = {}
	for _, register in ipairs(InstructionSet.Registers) do
		self.registers[register] = nil
	end

	self.flags = {
		zero = false,
		negative = false,
		greater = false,
	}

	self.state = {
		running = true,
		halted = false,
	}

	self.IP = options.entryAddress or 0
	self.stackBase = assert(options.stackBase, "CPU requires stackBase")
	self.stackTop = assert(options.stackTop, "CPU requires stackTop")
	self.SP = self.stackTop
	return self
end

function CPU:getRegister(name)
	assert(InstructionSet.isRegister(name), "Unknown register " .. tostring(name))
	return self.registers[name]
end

function CPU:setRegister(name, value)
	assert(InstructionSet.isRegister(name), "Unknown register " .. tostring(name))
	self.registers[name] = value
end

function CPU:_resolveOperand(operand)
	if type(operand) == "table" then
		local resolved = {}
		for key, value in pairs(operand) do
			resolved[self:_resolveOperand(key)] = self:_resolveOperand(value)
		end
		return resolved
	end

	if InstructionSet.isRegister(operand) then
		return self:getRegister(operand)
	end

	return operand
end

function CPU:_updateNumericFlags(value)
	self.flags.zero = value == 0
	self.flags.negative = type(value) == "number" and value < 0 or false
	self.flags.greater = type(value) == "number" and value > 0 or false
end

function CPU:_updateCompareFlags(left, right)
	self.flags.zero = left == right
	self.flags.negative = false
	self.flags.greater = false

	if type(left) == type(right) and (type(left) == "number" or type(left) == "string") then
		self.flags.negative = left < right
		self.flags.greater = left > right
	end
end

function CPU:_push(value)
	local nextAddress = self.SP - 1
	assert(nextAddress >= self.stackBase, "Stack overflow")
	self.memory:write(nextAddress, value)
	self.SP = nextAddress
end

function CPU:_pop()
	assert(self.SP < self.stackTop, "Stack underflow")
	local value = self.memory:read(self.SP)
	self.memory:write(self.SP, nil)
	self.SP += 1
	return value
end

function CPU:_logTrace(instruction)
	if not self.trace then
		return
	end

	local fields = {}
	for key, value in pairs(instruction) do
		if key ~= "op" then
			table.insert(fields, key .. "=" .. formatValue(value))
		end
	end

	table.sort(fields)
	self.logger(string.format("IP=%d SP=%d %s %s", self.IP, self.SP, instruction.op, table.concat(fields, " ")))
end

function CPU:_conditionMatches(condition)
	if condition == "eq" or condition == "z" then
		return self.flags.zero
	elseif condition == "ne" or condition == "nz" then
		return not self.flags.zero
	elseif condition == "lt" then
		return self.flags.negative
	elseif condition == "gt" then
		return self.flags.greater
	elseif condition == "le" then
		return self.flags.zero or self.flags.negative
	elseif condition == "ge" then
		return self.flags.zero or self.flags.greater
	end

	error("Unknown conditional jump condition " .. tostring(condition))
end

function CPU:halt()
	self.state.running = false
	self.state.halted = true
end

function CPU:step()
	assert(self.state.running, "CPU is not running")

	local instruction = self.memory:read(self.IP)
	assert(type(instruction) == "table" and instruction.op, string.format("No instruction mapped at address %d", self.IP))
	self:_logTrace(instruction)

	local nextIP = self.IP + 1

	if instruction.op == "NOP" then
		-- intentionally empty
	elseif instruction.op == "LOADK" then
		self:setRegister(instruction.a, instruction.b)
	elseif instruction.op == "MOV" then
		self:setRegister(instruction.a, self:_resolveOperand(instruction.b))
	elseif instruction.op == "LOAD" then
		local address = self:_resolveOperand(instruction.b)
		self:setRegister(instruction.a, self.memory:read(address))
	elseif instruction.op == "STORE" then
		local address = self:_resolveOperand(instruction.b)
		self.memory:write(address, self:_resolveOperand(instruction.a))
	elseif instruction.op == "ADD" then
		local left = self:_resolveOperand(instruction.b)
		local right = self:_resolveOperand(instruction.c)
		local value = nil
		if type(left) == "string" or type(right) == "string" then
			value = tostring(left) .. tostring(right)
		else
			value = left + right
		end
		self:setRegister(instruction.a, value)
		self:_updateNumericFlags(value)
	elseif instruction.op == "SUB" then
		local value = self:_resolveOperand(instruction.b) - self:_resolveOperand(instruction.c)
		self:setRegister(instruction.a, value)
		self:_updateNumericFlags(value)
	elseif instruction.op == "MUL" then
		local value = self:_resolveOperand(instruction.b) * self:_resolveOperand(instruction.c)
		self:setRegister(instruction.a, value)
		self:_updateNumericFlags(value)
	elseif instruction.op == "DIV" then
		local divisor = self:_resolveOperand(instruction.c)
		assert(divisor ~= 0, "Division by zero")
		local value = self:_resolveOperand(instruction.b) / divisor
		self:setRegister(instruction.a, value)
		self:_updateNumericFlags(value)
	elseif instruction.op == "CMP" then
		self:_updateCompareFlags(self:_resolveOperand(instruction.a), self:_resolveOperand(instruction.b))
	elseif instruction.op == "JMP" then
		nextIP = self:_resolveOperand(instruction.target)
	elseif instruction.op == "JMPIF" then
		if self:_conditionMatches(string.lower(tostring(instruction.condition))) then
			nextIP = self:_resolveOperand(instruction.target)
		end
	elseif instruction.op == "PUSH" then
		self:_push(self:_resolveOperand(instruction.a))
	elseif instruction.op == "POP" then
		self:setRegister(instruction.a, self:_pop())
	elseif instruction.op == "CALL" then
		self:_push(nextIP)
		nextIP = self:_resolveOperand(instruction.target)
	elseif instruction.op == "RET" then
		nextIP = self:_pop()
	elseif instruction.op == "SYSCALL" then
		local args = {}
		for index, operand in ipairs(instruction.args or {}) do
			args[index] = self:_resolveOperand(operand)
		end

		local result = self.onSyscall(self, {
			name = instruction.name,
			args = args,
			instruction = instruction,
		})

		if instruction.ret then
			self:setRegister(instruction.ret, result)
		end
	elseif instruction.op == "HALT" then
		self:halt()
	else
		error("Unsupported opcode " .. tostring(instruction.op))
	end

	self.IP = nextIP
	return instruction
end

function CPU:run(maxCycles)
	local cycles = 0
	local limit = maxCycles or 4096

	while self.state.running do
		self:step()
		cycles += 1
		assert(cycles <= limit, "CPU cycle limit exceeded")
	end

	return cycles
end

return CPU
