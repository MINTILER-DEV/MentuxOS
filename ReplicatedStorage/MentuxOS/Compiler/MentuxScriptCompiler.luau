local ExecutableFormat = require(script.Parent.Parent:WaitForChild("ExecutableFormat"))
local LibraryFormat = require(script.Parent.Parent:WaitForChild("LibraryFormat"))

local MentuxScriptCompiler = {}

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

		if character == "" then
			break
		elseif character:match("%s") then
			advance()
		elseif character == "/" and peek(1) == "/" then
			while index <= #source and peek() ~= "\n" do
				advance()
			end
		elseif character:match("[%a_]") then
			local start = index
			repeat
				advance()
			until not peek():match("[%w_]")
			addToken("identifier", source:sub(start, index - 1))
		elseif character:match("[%d]") then
			local start = index
			repeat
				advance()
			until not peek():match("[%d%.]")
			addToken("number", tonumber(source:sub(start, index - 1)))
		elseif character == '"' then
			advance()
			local parts = {}
			while index <= #source and peek() ~= '"' do
				local nextCharacter = advance()
				if nextCharacter == "\\" then
					local escaped = advance()
					if escaped == "n" then
						table.insert(parts, "\n")
					elseif escaped == "t" then
						table.insert(parts, "\t")
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

function Parser:finishCall(callee)
	self:expect("symbol", "(")
	local arguments = {}
	if not self:match("symbol", ")") then
		repeat
			table.insert(arguments, self:parseExpression())
		until not self:match("symbol", ",")
		self:expect("symbol", ")")
	end

	return {
		kind = "CallExpression",
		callee = callee.name,
		arguments = arguments,
	}
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
		local expression
		if token.value == "true" then
			expression = {
				kind = "Literal",
				value = true,
			}
		elseif token.value == "false" then
			expression = {
				kind = "Literal",
				value = false,
			}
		else
			expression = {
				kind = "Identifier",
				name = token.value,
			}
		end

		if expression.kind == "Identifier" and self:peek().kind == "symbol" and self:peek().value == "(" then
			return self:finishCall(expression)
		end

		return expression
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

	local expression = self:parseExpression()
	self:expect("symbol", ";")
	assert(expression.kind == "CallExpression", "Only function calls can be used as bare statements")
	return {
		kind = "ExpressionStatement",
		expression = expression,
	}
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

local BUILTIN_SYSCALLS = {
	print = { syscall = "write", statementOnly = false },
	readFile = { syscall = "readFile", returns = true },
	writeFile = { syscall = "writeFile", returns = true },
	appendFile = { syscall = "appendFile", returns = true },
	makeDir = { syscall = "mkdir", returns = true },
	deletePath = { syscall = "deletePath", returns = true },
	movePath = { syscall = "movePath", returns = true },
	listDir = { syscall = "listDir", returns = true },
	resolveExec = { syscall = "resolveExec", returns = true },
	resolvePath = { syscall = "resolvePath", returns = true },
	statKind = { syscall = "statKind", returns = true },
	fileInfo = { syscall = "fileInfo", returns = true },
	fileSummary = { syscall = "fileSummary", returns = true },
	httpRequest = { syscall = "http.request", returns = true },
	jsonParse = { syscall = "json.parse", returns = true },
	jsonStringify = { syscall = "json.encode", returns = true },
	libCall = { syscall = "lib.call", returns = true },
	libReturn = { syscall = "lib.return", returns = true, halts = true },
	sysInvoke = { syscall = "invoke", returns = true },
	exec = { syscall = "exec", returns = true },
	execAsync = { syscall = "exec.async", returns = true },
	envGet = { syscall = "env.get", returns = true },
	envSet = { syscall = "env.set", returns = true },
	guiReset = { syscall = "gui.reset", returns = true },
	guiBackground = { libraryPath = "/lib/ui/gui.mxl", exportName = "setBackgroundPreset", returns = true },
	guiWindow = { libraryPath = "/lib/ui/gui.mxl", exportName = "window", returns = true },
	guiPanel = { syscall = "gui.panel", returns = true },
	guiLabel = { syscall = "gui.label", returns = true },
	guiButton = { syscall = "gui.button", returns = true },
	guiEnableDrag = { syscall = "gui.setDraggable", returns = true },
	guiSetDraggable = { syscall = "gui.setDraggable", returns = true },
	guiTextBox = { syscall = "gui.textbox", returns = true },
	guiScrollFrame = { syscall = "gui.scrollFrame", returns = true },
	guiTextArea = { syscall = "gui.textarea", returns = true },
	guiRichText = { syscall = "gui.richText", returns = true },
	guiSetText = { syscall = "gui.setText", returns = true },
	guiGetText = { syscall = "gui.getText", returns = true },
	guiAppend = { syscall = "gui.appendText", returns = true },
	guiTweenPreset = { libraryPath = "/lib/ui/gui.mxl", exportName = "tweenPreset", returns = true },
	guiStylePreset = { libraryPath = "/lib/ui/gui.mxl", exportName = "applyStylePreset", returns = true },
	guiAnchor = { syscall = "gui.anchor", returns = true },
	guiCorner = { syscall = "gui.corner", returns = true },
	guiSetBackgroundColor = { syscall = "gui.setBackgroundColor", returns = true },
	guiSetTextColor = { syscall = "gui.setTextColor", returns = true },
	guiSetStrokeColor = { syscall = "gui.setStrokeColor", returns = true },
	guiSetSize = { syscall = "gui.setSize", returns = true },
	guiSetPosition = { syscall = "gui.setPosition", returns = true },
	guiSetVisible = { syscall = "gui.setVisible", returns = true },
	guiSetParent = { syscall = "gui.setParent", returns = true },
	guiSetZIndex = { syscall = "gui.setZIndex", returns = true },
	guiSetFont = { syscall = "gui.setFont", returns = true },
	guiSetTextSize = { syscall = "gui.setTextSize", returns = true },
	guiSetImage = { syscall = "gui.setImage", returns = true },
	guiTween = { syscall = "gui.tween", returns = true },
	guiPadding = { syscall = "gui.padding", returns = true },
	guiListLayout = { syscall = "gui.listLayout", returns = true },
	guiBackgroundTransparency = { syscall = "gui.backgroundTransparency", returns = true },
	guiTextTransparency = { syscall = "gui.textTransparency", returns = true },
	guiDestroy = { syscall = "gui.destroy", returns = true },
	guiWait = { syscall = "gui.waitEvent", returns = true },
	inputCapture = { syscall = "input.capture", returns = true },
	inputRelease = { syscall = "input.release", returns = true },
	inputClear = { syscall = "input.clear", returns = true },
	inputWait = { syscall = "input.wait", returns = true },
	len = { syscall = "value.len", returns = true },
	toNumber = { syscall = "value.toNumber", returns = true },
	charAt = { syscall = "str.charAt", returns = true },
	substr = { libraryPath = "/lib/core/string.mxl", exportName = "substr", returns = true },
	splitText = { libraryPath = "/lib/core/string.mxl", exportName = "split", returns = true },
	concat = { libraryPath = "/lib/core/string.mxl", exportName = "concat", returns = true },
	listNew = { syscall = "list.new", returns = true },
	push = { syscall = "list.push", returns = true },
	get = { syscall = "list.get", returns = true },
	mapGet = { syscall = "map.get", returns = true },
	objNew = { syscall = "obj.new", returns = true },
	objGet = { syscall = "obj.get", returns = true },
	objSet = { syscall = "obj.set", returns = true },
	sliceList = { syscall = "list.slice", returns = true },
	argc = { syscall = "proc.argc", returns = true },
	pid = { syscall = "proc.pid", returns = true },
	argv = { syscall = "proc.argv", returns = true },
	listProcesses = { syscall = "proc.list", returns = true },
	killProcess = { syscall = "proc.kill", returns = true },
	exists = { syscall = "exists", returns = true },
	stat = { syscall = "stat", returns = true },
	exit = { syscall = "exit", returns = true, halts = true },
}

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
		metadata = deepCopy(options.metadata or {}),
		code = {},
		data = {},
		variables = {},
		nextDataOffset = 0,
		labels = {},
		labelCounter = 0,
		freeRegisters = { "R7", "R6", "R5", "R4", "R3", "R2", "R1", "R0" },
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
	if register then
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

function CodeGenerator:emitOperand(expression)
	if expression.kind == "Literal" then
		return expression.value, nil
	end

	local register = self:emitExpression(expression)
	return register, register
end

function CodeGenerator:emitCall(expression, wantResult)
	local builtin = BUILTIN_SYSCALLS[expression.callee]
	assert(builtin, "Unknown MentuxScript builtin " .. tostring(expression.callee))

	local syscallArgs = {}
	local borrowedRegisters = {}
	for index, argument in ipairs(expression.arguments) do
		local operand, borrowedRegister = self:emitOperand(argument)
		syscallArgs[index] = operand
		if borrowedRegister then
			table.insert(borrowedRegisters, borrowedRegister)
		end
	end

	local resultRegister = nil
	if wantResult and builtin.returns ~= false then
		resultRegister = self:allocRegister()
	end

	if builtin.libraryPath then
		self:emit("SYSCALL", {
			name = "lib.call",
			args = {
				builtin.libraryPath,
				builtin.exportName,
				syscallArgs,
			},
			ret = resultRegister,
		})
	else
		self:emit("SYSCALL", {
			name = builtin.syscall,
			args = syscallArgs,
			ret = resultRegister,
		})
	end

	for _, argumentRegister in ipairs(borrowedRegisters) do
		self:freeRegister(argumentRegister)
	end

	if builtin.halts then
		self:emit("HALT")
	end

	return resultRegister
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
	elseif expression.kind == "CallExpression" then
		return self:emitCall(expression, true)
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
	elseif statement.kind == "ExpressionStatement" then
		local resultRegister = self:emitCall(statement.expression, false)
		self:freeRegister(resultRegister)
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

function CodeGenerator:compile(ast, options)
	options = options or {}
	for _, statement in ipairs(ast.body) do
		self:emitStatement(statement)
	end

	if self.code[#self.code] == nil or self.code[#self.code].op ~= "HALT" then
		self:emit("HALT")
	end

	self:resolveLabels()

	local metadata = deepCopy(self.metadata)
	metadata.compiler = "MentuxScriptCompiler"
	metadata.language = "MentuxScript"
	metadata.instructionCount = #self.code
	metadata.dataCells = #self.data

	return ExecutableFormat.new({
		name = self.name,
		kind = options.imageKind or "program",
		entryPoint = options.entryPoint or 0,
		stackSize = self.stackSize,
		code = deepCopy(self.code),
		constants = {},
		data = deepCopy(self.data),
		metadata = metadata,
	})
end

function MentuxScriptCompiler.parse(source)
	local tokens = Tokenizer.tokenize(source)
	local parser = Parser.new(tokens)
	return parser:parseProgram()
end

function MentuxScriptCompiler.compile(source, options)
	options = options or {}

	if options.kind == "library" then
		local exportName = options.exportName or "main"
		local libraryName = options.name or "compiled-library"
		local exportImage = MentuxScriptCompiler.compile(source, {
			name = string.format("%s::%s", libraryName, exportName),
			stackSize = options.stackSize,
			metadata = options.metadata,
			compiledKind = "library-export",
		})

		return LibraryFormat.new({
			name = libraryName,
			exports = {
				[exportName] = exportImage,
			},
			metadata = deepCopy(options.libraryMetadata or options.metadata or {}),
		})
	end

	local ast = MentuxScriptCompiler.parse(source)
	local generator = CodeGenerator.new({
		name = options.name,
		stackSize = options.stackSize,
		metadata = options.metadata,
	})
	return generator:compile(ast, {
		imageKind = options.compiledKind or "program",
	})
end

function MentuxScriptCompiler.compileLibrary(exports, options)
	options = options or {}
	assert(type(exports) == "table", "compileLibrary expects an export map")

	local libraryName = options.name or "compiled-library"
	local compiledExports = {}
	for exportName, exportSource in pairs(exports) do
		compiledExports[exportName] = MentuxScriptCompiler.compile(exportSource, {
			name = string.format("%s::%s", libraryName, exportName),
			stackSize = options.stackSize,
			metadata = deepCopy((options.exportMetadata or {})[exportName] or options.metadata or {}),
			compiledKind = "library-export",
		})
	end

	return LibraryFormat.new({
		name = libraryName,
		exports = compiledExports,
		metadata = deepCopy(options.libraryMetadata or options.metadata or {}),
	})
end

return MentuxScriptCompiler
