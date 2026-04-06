local MentuxCompiler = {}

local function deepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local clone = {}
	seen[value] = clone
	for key, nestedValue in pairs(value) do
		clone[deepCopy(key, seen)] = deepCopy(nestedValue, seen)
	end
	return clone
end

local Tokenizer = {}

function Tokenizer.tokenize(source)
	local tokens = {}
	local index = 1
	local line = 1
	local column = 1

	local function peek(offset)
		return source:sub(index + (offset or 0), index + (offset or 0))
	end

	local function advance()
		local character = peek()
		index += 1
		if character == "\n" then
			line += 1
			column = 1
		else
			column += 1
		end
		return character
	end

	local function addToken(kind, value)
		table.insert(tokens, {
			kind = kind,
			value = value,
			line = line,
			column = column,
		})
	end

	while index <= #source do
		local character = peek()

		if character:match("%s") then
			advance()
		elseif character == "/" and peek(1) == "/" then
			while index <= #source and peek() ~= "\n" do
				advance()
			end
		elseif character:match("[%a_]") then
			local start = index
			while peek():match("[%w_]") do
				advance()
			end
			local value = source:sub(start, index - 1)
			addToken("identifier", value)
		elseif character:match("%d") then
			local start = index
			while peek():match("[%d%.]") do
				advance()
			end
			local value = tonumber(source:sub(start, index - 1))
			addToken("number", value)
		elseif character == '"' then
			advance()
			local parts = {}
			while index <= #source and peek() ~= '"' do
				local nextCharacter = advance()
				if nextCharacter == "\\" then
					local escaped = advance()
					if escaped == "n" then
						table.insert(parts, "\n")
					else
						table.insert(parts, escaped)
					end
				else
					table.insert(parts, nextCharacter)
				end
			end
			assert(peek() == '"', "Unterminated string literal")
			advance()
			addToken("string", table.concat(parts))
		else
			local twoCharacter = character .. peek(1)
			if twoCharacter == "==" or twoCharacter == "!=" or twoCharacter == "<=" or twoCharacter == ">=" then
				addToken("symbol", twoCharacter)
				advance()
				advance()
			else
				addToken("symbol", character)
				advance()
			end
		end
	end

	table.insert(tokens, {
		kind = "eof",
		value = "<eof>",
		line = line,
		column = column,
	})

	return tokens
end

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
	return setmetatable({
		tokens = tokens,
		index = 1,
	}, Parser)
end

function Parser:peek(offset)
	return self.tokens[self.index + (offset or 0)]
end

function Parser:advance()
	local token = self:peek()
	self.index += 1
	return token
end

function Parser:match(kind, value)
	local token = self:peek()
	if token.kind == kind and (value == nil or token.value == value) then
		self:advance()
		return token
	end
	return nil
end

function Parser:expect(kind, value)
	local token = self:advance()
	assert(token.kind == kind and (value == nil or token.value == value), string.format("Expected %s %s, got %s %s", tostring(kind), tostring(value), tostring(token.kind), tostring(token.value)))
	return token
end

function Parser:parsePrimary()
	local token = self:peek()

	if self:match("symbol", "(") then
		local expression = self:parseExpression()
		self:expect("symbol", ")")
		return expression
	elseif token.kind == "number" then
		self:advance()
		return {
			kind = "Literal",
			value = token.value,
		}
	elseif token.kind == "string" then
		self:advance()
		return {
			kind = "Literal",
			value = token.value,
		}
	elseif token.kind == "identifier" then
		self:advance()
		if token.value == "true" then
			return {
				kind = "Literal",
				value = true,
			}
		elseif token.value == "false" then
			return {
				kind = "Literal",
				value = false,
			}
		end

		return {
			kind = "Identifier",
			name = token.value,
		}
	end

	error("Unexpected token " .. tostring(token.value))
end

function Parser:parseUnary()
	if self:match("symbol", "-") then
		return {
			kind = "UnaryExpression",
			operator = "-",
			argument = self:parseUnary(),
		}
	end

	return self:parsePrimary()
end

function Parser:parseFactor()
	local expression = self:parseUnary()

	while true do
		local operator = self:match("symbol", "*") or self:match("symbol", "/")
		if not operator then
			break
		end

		expression = {
			kind = "BinaryExpression",
			operator = operator.value,
			left = expression,
			right = self:parseUnary(),
		}
	end

	return expression
end

function Parser:parseTerm()
	local expression = self:parseFactor()

	while true do
		local operator = self:match("symbol", "+") or self:match("symbol", "-")
		if not operator then
			break
		end

		expression = {
			kind = "BinaryExpression",
			operator = operator.value,
			left = expression,
			right = self:parseFactor(),
		}
	end

	return expression
end

function Parser:parseComparison()
	local expression = self:parseTerm()
	local operator = self:match("symbol", "==")
		or self:match("symbol", "!=")
		or self:match("symbol", "<")
		or self:match("symbol", "<=")
		or self:match("symbol", ">")
		or self:match("symbol", ">=")

	if operator then
		expression = {
			kind = "BinaryExpression",
			operator = operator.value,
			left = expression,
			right = self:parseTerm(),
		}
	end

	return expression
end

function Parser:parseExpression()
	return self:parseComparison()
end

function Parser:parseBlock()
	self:expect("symbol", "{")
	local statements = {}
	while not self:match("symbol", "}") do
		table.insert(statements, self:parseStatement())
	end
	return statements
end

function Parser:parseStatement()
	local token = self:peek()

	if token.kind == "identifier" and token.value == "let" then
		self:advance()
		local name = self:expect("identifier").value
		self:expect("symbol", "=")
		local expression = self:parseExpression()
		self:expect("symbol", ";")
		return {
			kind = "LetStatement",
			name = name,
			expression = expression,
		}
	elseif token.kind == "identifier" and token.value == "print" then
		self:advance()
		local expression = self:parseExpression()
		self:expect("symbol", ";")
		return {
			kind = "PrintStatement",
			expression = expression,
		}
	elseif token.kind == "identifier" and token.value == "exit" then
		self:advance()
		local expression = self:parseExpression()
		self:expect("symbol", ";")
		return {
			kind = "ExitStatement",
			expression = expression,
		}
	elseif token.kind == "identifier" and token.value == "run" then
		self:advance()
		local pathExpression = self:parseExpression()
		local argExpression = nil
		if self:match("symbol", ",") then
			argExpression = self:parseExpression()
		end
		self:expect("symbol", ";")
		return {
			kind = "RunStatement",
			pathExpression = pathExpression,
			argExpression = argExpression,
		}
	elseif token.kind == "identifier" and token.value == "if" then
		self:advance()
		local condition = self:parseExpression()
		local thenBody = self:parseBlock()
		local elseBody = nil
		if self:peek().kind == "identifier" and self:peek().value == "else" then
			self:advance()
			elseBody = self:parseBlock()
		end
		return {
			kind = "IfStatement",
			condition = condition,
			thenBody = thenBody,
			elseBody = elseBody,
		}
	elseif token.kind == "identifier" and token.value == "while" then
		self:advance()
		local condition = self:parseExpression()
		local body = self:parseBlock()
		return {
			kind = "WhileStatement",
			condition = condition,
			body = body,
		}
	elseif token.kind == "identifier" and self:peek(1).kind == "symbol" and self:peek(1).value == "=" then
		local name = self:advance().value
		self:expect("symbol", "=")
		local expression = self:parseExpression()
		self:expect("symbol", ";")
		return {
			kind = "AssignStatement",
			name = name,
			expression = expression,
		}
	end

	error("Unsupported statement starting with " .. tostring(token.value))
end

function Parser:parseProgram()
	local statements = {}
	while self:peek().kind ~= "eof" do
		table.insert(statements, self:parseStatement())
	end
	return {
		kind = "Program",
		body = statements,
	}
end

local CodeGenerator = {}
CodeGenerator.__index = CodeGenerator

local COMPARISON_JUMPS = {
	["=="] = "ne",
	["!="] = "eq",
	[">"] = "le",
	[">="] = "lt",
	["<"] = "ge",
	["<="] = "gt",
}

local ARITHMETIC_OPS = {
	["+"] = "ADD",
	["-"] = "SUB",
	["*"] = "MUL",
	["/"] = "DIV",
}

function CodeGenerator.new(options)
	return setmetatable({
		name = options.name or "compiled-program",
		stackSize = options.stackSize or 128,
		code = {},
		data = {},
		variables = {},
		nextDataOffset = 0,
		labels = {},
		labelCounter = 0,
		freeRegisters = { "R7", "R6", "R5", "R4", "R0" },
	}, CodeGenerator)
end

function CodeGenerator:emit(op, payload)
	local instruction = payload and deepCopy(payload) or {}
	instruction.op = op
	table.insert(self.code, instruction)
	return #self.code
end

function CodeGenerator:placeLabel(name)
	self.labels[name] = #self.code
end

function CodeGenerator:newLabel(prefix)
	self.labelCounter += 1
	return string.format("%s_%d", prefix, self.labelCounter)
end

function CodeGenerator:allocRegister()
	local register = table.remove(self.freeRegisters)
	assert(register ~= nil, "Out of VM registers while compiling expression")
	return register
end

function CodeGenerator:freeRegister(register)
	if register and register ~= "R1" and register ~= "R2" and register ~= "R3" then
		table.insert(self.freeRegisters, register)
	end
end

function CodeGenerator:ensureVariable(name)
	if self.variables[name] == nil then
		self.variables[name] = self.nextDataOffset
		table.insert(self.data, {
			offset = self.nextDataOffset,
			value = 0,
		})
		self.nextDataOffset += 1
	end
	return self.variables[name]
end

function CodeGenerator:dataRef(offset)
	return {
		section = "data",
		offset = offset,
	}
end

function CodeGenerator:emitExpression(expression)
	if expression.kind == "Literal" then
		local target = self:allocRegister()
		self:emit("LOADK", {
			a = target,
			b = expression.value,
		})
		return target
	elseif expression.kind == "Identifier" then
		local offset = self:ensureVariable(expression.name)
		local target = self:allocRegister()
		self:emit("LOAD", {
			a = target,
			b = self:dataRef(offset),
		})
		return target
	elseif expression.kind == "UnaryExpression" and expression.operator == "-" then
		local source = self:emitExpression(expression.argument)
		local zeroRegister = self:allocRegister()
		self:emit("LOADK", {
			a = zeroRegister,
			b = 0,
		})
		self:emit("SUB", {
			a = source,
			b = zeroRegister,
			c = source,
		})
		self:freeRegister(zeroRegister)
		return source
	elseif expression.kind == "BinaryExpression" and ARITHMETIC_OPS[expression.operator] then
		local leftRegister = self:emitExpression(expression.left)
		local rightRegister = self:emitExpression(expression.right)
		self:emit(ARITHMETIC_OPS[expression.operator], {
			a = leftRegister,
			b = leftRegister,
			c = rightRegister,
		})
		self:freeRegister(rightRegister)
		return leftRegister
	end

	error("Unsupported expression for direct value codegen: " .. tostring(expression.kind))
end

function CodeGenerator:emitCondition(expression, falseLabel)
	if expression.kind == "BinaryExpression" and COMPARISON_JUMPS[expression.operator] then
		local leftRegister = self:emitExpression(expression.left)
		local rightRegister = self:emitExpression(expression.right)
		self:emit("CMP", {
			a = leftRegister,
			b = rightRegister,
		})
		self:emit("JMPIF", {
			condition = COMPARISON_JUMPS[expression.operator],
			target = falseLabel,
		})
		self:freeRegister(leftRegister)
		self:freeRegister(rightRegister)
		return
	end

	local valueRegister = self:emitExpression(expression)
	self:emit("CMP", {
		a = valueRegister,
		b = false,
	})
	self:emit("JMPIF", {
		condition = "eq",
		target = falseLabel,
	})
	self:freeRegister(valueRegister)
end

function CodeGenerator:emitStatement(statement)
	if statement.kind == "LetStatement" or statement.kind == "AssignStatement" then
		local register = self:emitExpression(statement.expression)
		local offset = self:ensureVariable(statement.name)
		self:emit("STORE", {
			a = register,
			b = self:dataRef(offset),
		})
		self:freeRegister(register)
	elseif statement.kind == "PrintStatement" then
		local register = self:emitExpression(statement.expression)
		self:emit("SYSCALL", {
			name = "write",
			args = { register },
			ret = "R7",
		})
		self:freeRegister(register)
	elseif statement.kind == "ExitStatement" then
		local register = self:emitExpression(statement.expression)
		self:emit("SYSCALL", {
			name = "exit",
			args = { register },
			ret = "R7",
		})
		self:emit("HALT")
		self:freeRegister(register)
	elseif statement.kind == "RunStatement" then
		local pathRegister = self:emitExpression(statement.pathExpression)
		local args = { pathRegister }
		local argRegister = nil
		if statement.argExpression then
			argRegister = self:emitExpression(statement.argExpression)
			table.insert(args, argRegister)
		end
		self:emit("SYSCALL", {
			name = "exec",
			args = args,
			ret = "R7",
		})
		self:freeRegister(pathRegister)
		self:freeRegister(argRegister)
	elseif statement.kind == "IfStatement" then
		local falseLabel = self:newLabel("if_false")
		local endLabel = self:newLabel("if_end")
		self:emitCondition(statement.condition, falseLabel)
		for _, nestedStatement in ipairs(statement.thenBody) do
			self:emitStatement(nestedStatement)
		end
		if statement.elseBody then
			self:emit("JMP", {
				target = endLabel,
			})
		end
		self:placeLabel(falseLabel)
		if statement.elseBody then
			for _, nestedStatement in ipairs(statement.elseBody) do
				self:emitStatement(nestedStatement)
			end
			self:placeLabel(endLabel)
		end
	elseif statement.kind == "WhileStatement" then
		local loopLabel = self:newLabel("while_loop")
		local endLabel = self:newLabel("while_end")
		self:placeLabel(loopLabel)
		self:emitCondition(statement.condition, endLabel)
		for _, nestedStatement in ipairs(statement.body) do
			self:emitStatement(nestedStatement)
		end
		self:emit("JMP", {
			target = loopLabel,
		})
		self:placeLabel(endLabel)
	else
		error("Unsupported statement kind " .. tostring(statement.kind))
	end
end

function CodeGenerator:resolveLabels()
	for _, instruction in ipairs(self.code) do
		if (instruction.op == "JMP" or instruction.op == "JMPIF" or instruction.op == "CALL") and type(instruction.target) == "string" then
			assert(self.labels[instruction.target] ~= nil, "Unknown label " .. instruction.target)
			instruction.target = self.labels[instruction.target]
		end
	end
end

function CodeGenerator:compile(ast)
	for _, statement in ipairs(ast.body) do
		self:emitStatement(statement)
	end

	if self.code[#self.code] == nil or self.code[#self.code].op ~= "HALT" then
		self:emit("HALT")
	end

	self:resolveLabels()

	return {
		magic = "MENTUX_EXEC",
		version = 1,
		name = self.name,
		kind = "program",
		entryPoint = 0,
		stackSize = self.stackSize,
		code = deepCopy(self.code),
		constants = {},
		data = deepCopy(self.data),
		metadata = {
			compiler = "External/MentuxCompiler.luau",
			language = "MentuxScript",
		},
	}
end

function MentuxCompiler.parse(source)
	local tokens = Tokenizer.tokenize(source)
	local parser = Parser.new(tokens)
	return parser:parseProgram()
end

function MentuxCompiler.compile(source, options)
	options = options or {}
	local ast = MentuxCompiler.parse(source)
	local generator = CodeGenerator.new({
		name = options.name,
		stackSize = options.stackSize,
	})
	return generator:compile(ast)
end

return MentuxCompiler
