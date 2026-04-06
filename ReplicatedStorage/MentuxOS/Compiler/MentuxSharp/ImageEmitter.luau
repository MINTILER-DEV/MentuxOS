local ImageEmitter = {}

local EXEC_MAGIC = "MENTUX_EXEC"
local LIB_MAGIC = "MENTUX_LIB"
local VERSION = 1

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

local function newExecutable(spec)
	return {
		magic = EXEC_MAGIC,
		version = VERSION,
		name = spec.name or "unnamed",
		kind = spec.kind or "program",
		entryPoint = spec.entryPoint or 0,
		stackSize = spec.stackSize or 128,
		code = deepCopy(spec.code or {}),
		constants = deepCopy(spec.constants or {}),
		data = deepCopy(spec.data or {}),
		metadata = deepCopy(spec.metadata or {}),
	}
end

local function newLibrary(spec)
	return {
		magic = LIB_MAGIC,
		version = VERSION,
		name = spec.name or "unnamed-library",
		kind = spec.kind or "library",
		exports = deepCopy(spec.exports or {}),
		metadata = deepCopy(spec.metadata or {}),
	}
end

local function dataRef(offset)
	return {
		section = "data",
		offset = offset,
	}
end

local function append(list, value)
	list[#list + 1] = value
	return value
end

local function listToText(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for index, item in ipairs(value) do
		parts[index] = tostring(item)
	end
	return "[" .. table.concat(parts, ", ") .. "]"
end

local function encodeSharpLibraryPath(namespaces)
	if type(namespaces) ~= "table" or #namespaces == 0 then
		return nil
	end
	return "sharp:" .. table.concat(namespaces, ";")
end

local ProgramEmitter = {}
ProgramEmitter.__index = ProgramEmitter

local DIRECT_SYMBOL_CALLS = {
	["Runtime.Json.parse"] = { kind = "syscall", name = "json.parse" },
	["Runtime.Json.stringify"] = { kind = "syscall", name = "json.encode" },
	["Runtime.Env.get"] = { kind = "syscall", name = "env.get" },
	["Runtime.Env.set"] = { kind = "syscall", name = "env.set" },
	["Runtime.Value.len"] = { kind = "syscall", name = "value.len" },
	["Runtime.Value.toNumber"] = { kind = "syscall", name = "value.toNumber" },
	["Runtime.String.charAt"] = { kind = "syscall", name = "str.charAt" },
	["Runtime.String.substr"] = { kind = "library", libraryPath = "/lib/core/string.mxl", exportName = "substr" },
	["Runtime.String.split"] = { kind = "library", libraryPath = "/lib/core/string.mxl", exportName = "split" },
	["Runtime.String.concat"] = { kind = "library", libraryPath = "/lib/core/string.mxl", exportName = "concat" },
	["Runtime.List.new"] = { kind = "syscall", name = "list.new" },
	["Runtime.List.push"] = { kind = "syscall", name = "list.push" },
	["Runtime.List.get"] = { kind = "syscall", name = "list.get" },
	["Runtime.List.slice"] = { kind = "syscall", name = "list.slice" },
	["Runtime.Map.get"] = { kind = "syscall", name = "map.get" },
	["Runtime.Process.argc"] = { kind = "syscall", name = "proc.argc" },
	["Runtime.Process.argv"] = { kind = "syscall", name = "proc.argv" },
	["Runtime.Process.pid"] = { kind = "syscall", name = "proc.pid" },
	["Runtime.Process.list"] = { kind = "syscall", name = "proc.list" },
	["File.read"] = { kind = "syscall", name = "readFile" },
	["File.write"] = { kind = "syscall", name = "writeFile" },
	["File.append"] = { kind = "syscall", name = "appendFile" },
	["File.exists"] = { kind = "syscall", name = "exists" },
	["File.listDir"] = { kind = "syscall", name = "listDir" },
	["File.stat"] = { kind = "syscall", name = "stat" },
	["File.statKind"] = { kind = "syscall", name = "statKind" },
	["File.resolvePath"] = { kind = "syscall", name = "resolvePath" },
	["Runtime.Gui.reset"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "reset" },
	["Runtime.Gui.background"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "setBackgroundPreset" },
	["Runtime.Gui.window"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "window" },
	["Runtime.Gui.panel"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "panel" },
	["Runtime.Gui.label"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "label" },
	["Runtime.Gui.button"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "button" },
	["Runtime.Gui.enableDrag"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "setDraggable" },
	["Runtime.Gui.textBox"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "textBox" },
	["Runtime.Gui.textArea"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "textArea" },
	["Runtime.Gui.richText"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "richText" },
	["Runtime.Gui.scrollFrame"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "scrollFrame" },
	["Runtime.Gui.setText"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "setText" },
	["Runtime.Gui.getText"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "getText" },
	["Runtime.Gui.appendText"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "appendText" },
	["Runtime.Gui.tweenPreset"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "tweenPreset" },
	["Runtime.Gui.stylePreset"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "applyStylePreset" },
	["Runtime.Gui.anchor"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "anchor" },
	["Runtime.Gui.corner"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "corner" },
	["Runtime.Gui.padding"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "padding" },
	["Runtime.Gui.listLayout"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "listLayout" },
	["Runtime.Gui.backgroundTransparency"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "backgroundTransparency" },
	["Runtime.Gui.textTransparency"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "textTransparency" },
	["Runtime.Gui.waitEvent"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "waitEvent" },
	["Runtime.Gui.destroy"] = { kind = "library", libraryPath = "/lib/ui/gui.mxl", exportName = "destroy" },
}

local THROWING_SYSCALLS = {
	["json.parse"] = true,
	["json.encode"] = true,
	["readFile"] = true,
	["writeFile"] = true,
	["appendFile"] = true,
	["mkdir"] = true,
	["deletePath"] = true,
	["movePath"] = true,
	["stat"] = true,
	["listDir"] = true,
	["exec"] = true,
	["lib.call"] = true,
	["obj.get"] = true,
	["obj.set"] = true,
	["obj.callMethod"] = true,
	["exc.raisePending"] = true,
}

local function shortTypeName(fullName)
	local match = tostring(fullName or ""):match("([^.]+)$")
	return match or tostring(fullName or "Object")
end

local function methodExportName(irFunction)
	if irFunction.isConstructor then
		return string.format("%s.ctor", shortTypeName(irFunction.ownerType))
	end
	return string.format("%s.%s", shortTypeName(irFunction.ownerType), irFunction.name)
end

function ProgramEmitter.new(options)
	return setmetatable({
		name = options.name,
		kind = options.kind or "program",
		exportName = options.exportName,
		moduleKind = options.moduleKind,
		stackSize = options.stackSize or 128,
		code = {},
		data = {},
		variables = {},
		nextDataOffset = 0,
		labels = {},
		labelCounter = 0,
		freeRegisters = { "R7", "R6", "R5", "R4", "R3", "R2", "R1", "R0" },
		warnings = {},
		activeTryContext = nil,
	}, ProgramEmitter)
end

function ProgramEmitter:warn(message)
	table.insert(self.warnings, message)
end

function ProgramEmitter:emit(op, payload)
	local instruction = deepCopy(payload or {})
	instruction.op = op
	table.insert(self.code, instruction)
	return #self.code
end

function ProgramEmitter:newLabel(prefix)
	self.labelCounter += 1
	return string.format("%s_%d", prefix, self.labelCounter)
end

function ProgramEmitter:placeLabel(name)
	self.labels[name] = #self.code
end

function ProgramEmitter:resolveLabels()
	for _, instruction in ipairs(self.code) do
		if (instruction.op == "JMP" or instruction.op == "JMPIF" or instruction.op == "CALL") and type(instruction.target) == "string" then
			assert(self.labels[instruction.target] ~= nil, "Unknown label " .. instruction.target)
			instruction.target = self.labels[instruction.target]
		end
	end
end

function ProgramEmitter:allocRegister()
	local register = table.remove(self.freeRegisters)
	assert(register ~= nil, "Out of VM registers while emitting MT# image")
	return register
end

function ProgramEmitter:freeRegister(register)
	if register then
		table.insert(self.freeRegisters, register)
	end
end

function ProgramEmitter:ensureVariable(name, initialValue)
	if self.variables[name] == nil then
		self.variables[name] = self.nextDataOffset
		table.insert(self.data, {
			offset = self.nextDataOffset,
			value = initialValue,
		})
		self.nextDataOffset += 1
	end
	return self.variables[name]
end

function ProgramEmitter:storeRegister(register, name)
	local offset = self:ensureVariable(name, nil)
	self:emit("STORE", {
		a = register,
		b = dataRef(offset),
	})
end

function ProgramEmitter:storeConstant(value, name)
	local register = self:allocRegister()
	self:emit("LOADK", {
		a = register,
		b = value,
	})
	self:storeRegister(register, name)
	self:freeRegister(register)
end

function ProgramEmitter:loadVariable(name)
	local offset = self:ensureVariable(name, nil)
	local target = self:allocRegister()
	self:emit("LOAD", {
		a = target,
		b = dataRef(offset),
	})
	return target
end

function ProgramEmitter:emitProcArg(index)
	local target = self:allocRegister()
	self:emit("SYSCALL", {
		name = "proc.argv",
		args = { index },
		ret = target,
	})
	return target
end

function ProgramEmitter:emitExceptionCheck(targetLabel)
	local exceptionLabel = targetLabel or (self.activeTryContext and self.activeTryContext.exceptionLabel)
	if not exceptionLabel then
		return
	end

	local hasExceptionRegister = self:allocRegister()
	self:emit("SYSCALL", {
		name = "exc.has",
		args = {},
		ret = hasExceptionRegister,
	})
	self:emit("CMP", {
		a = hasExceptionRegister,
		b = true,
	})
	self:emit("JMPIF", {
		condition = "eq",
		target = exceptionLabel,
	})
	self:freeRegister(hasExceptionRegister)
end

function ProgramEmitter:emitDynamicArgsList(values)
	local listRegister = self:allocRegister()
	self:emit("SYSCALL", {
		name = "list.new",
		args = {},
		ret = listRegister,
	})

	for _, value in ipairs(values) do
		self:emit("SYSCALL", {
			name = "list.push",
			args = { listRegister, value },
			ret = listRegister,
		})
	end

	return listRegister
end

function ProgramEmitter:emitSyscall(syscallName, args, retRegister, canThrow)
	if self.activeTryContext and canThrow then
		local argsListRegister = self:emitDynamicArgsList(args or {})
		self:emit("SYSCALL", {
			name = "safe.invoke",
			args = { syscallName, argsListRegister },
			ret = retRegister,
		})
		self:freeRegister(argsListRegister)
		self:emitExceptionCheck()
		return
	end

	self:emit("SYSCALL", {
		name = syscallName,
		args = args or {},
		ret = retRegister,
	})
end

function ProgramEmitter:buildArgPayload(expressions)
	if #expressions == 0 then
		return nil, nil
	end

	if #expressions == 1 then
		return self:emitExpression(expressions[1]), true
	end

	local listRegister = self:allocRegister()
	self:emit("SYSCALL", {
		name = "list.new",
		args = {},
		ret = listRegister,
	})

	for _, argument in ipairs(expressions) do
		local valueRegister = self:emitExpression(argument)
		self:emit("SYSCALL", {
			name = "list.push",
			args = { listRegister, valueRegister },
			ret = listRegister,
		})
		self:freeRegister(valueRegister)
	end

	return listRegister, true
end

function ProgramEmitter:emitCallBySyscall(syscallName, expressions, wantResult, prefixArgs)
	local argsListRegister = self:allocRegister()
	self:emit("SYSCALL", {
		name = "list.new",
		args = {},
		ret = argsListRegister,
	})

	for _, value in ipairs(prefixArgs or {}) do
		self:emit("SYSCALL", {
			name = "list.push",
			args = { argsListRegister, value },
			ret = argsListRegister,
		})
	end

	for _, expression in ipairs(expressions or {}) do
		local register = self:emitExpression(expression)
		self:emit("SYSCALL", {
			name = "list.push",
			args = { argsListRegister, register },
			ret = argsListRegister,
		})
		self:freeRegister(register)
	end

	local retRegister = nil
	if wantResult then
		retRegister = self:allocRegister()
	end

	local invokeName = "invoke"
	if self.activeTryContext and THROWING_SYSCALLS[syscallName] == true then
		invokeName = "safe.invoke"
	end

	self:emit("SYSCALL", {
		name = invokeName,
		args = { syscallName, argsListRegister },
		ret = retRegister,
	})
	self:freeRegister(argsListRegister)

	if invokeName == "safe.invoke" then
		self:emitExceptionCheck()
	end

	return retRegister
end

function ProgramEmitter:emitCallExpression(expression, wantResult)
	if expression.kind == "call_library" then
		local payloadRegister, borrowed = self:buildArgPayload(expression.arguments)
		local args = {
			expression.libraryPath,
			expression.exportName,
		}
		if payloadRegister ~= nil then
			table.insert(args, payloadRegister)
		end
		local retRegister = nil
		if wantResult then
			retRegister = self:allocRegister()
		end
		self:emitSyscall("lib.call", args, retRegister, true)
		if borrowed then
			self:freeRegister(payloadRegister)
		end
		return retRegister
	end

	if expression.kind == "call_embedded" then
		local payloadRegister, borrowed = self:buildArgPayload(expression.arguments)
		local args = {
			expression.sourcePath,
		}
		if payloadRegister ~= nil then
			table.insert(args, payloadRegister)
		end
		local retRegister = nil
		if wantResult then
			retRegister = self:allocRegister()
		end
		self:emitSyscall("exec", args, retRegister, THROWING_SYSCALLS.exec == true)
		if borrowed then
			self:freeRegister(payloadRegister)
		end
		return retRegister
	end

	if expression.kind == "call_symbol" then
		local path = table.concat(expression.path or {}, ".")
		local directCall = DIRECT_SYMBOL_CALLS[path]
		if directCall then
			if directCall.kind == "library" then
				return self:emitCallExpression({
					kind = "call_library",
					libraryPath = directCall.libraryPath,
					exportName = directCall.exportName,
					arguments = expression.arguments,
				}, wantResult)
			end
			return self:emitCallBySyscall(directCall.name, expression.arguments, wantResult)
		end
		if path == "print" then
			return self:emitCallBySyscall("write", expression.arguments, wantResult)
		end
		local sharpLibraryPath = encodeSharpLibraryPath(expression.sharpNamespaces)
		if sharpLibraryPath then
			local payloadRegister, borrowed = self:buildArgPayload(expression.arguments)
			local args = {
				sharpLibraryPath,
				path,
			}
			if payloadRegister ~= nil then
				table.insert(args, payloadRegister)
			end
			local retRegister = nil
			if wantResult then
				retRegister = self:allocRegister()
			end
			self:emitSyscall("lib.call", args, retRegister, true)
			if borrowed then
				self:freeRegister(payloadRegister)
			end
			return retRegister
		end
		error("Unsupported MT# symbol call for executable emission: " .. path)
	end

	if expression.kind == "call_self_method" then
		local selfRegister = self:loadVariable("self")
		local payloadRegister, borrowed = self:buildArgPayload(expression.arguments)
		local args = {
			selfRegister,
			expression.member,
		}
		if payloadRegister ~= nil then
			table.insert(args, payloadRegister)
		end
		local retRegister = nil
		if wantResult then
			retRegister = self:allocRegister()
		end
		self:emitSyscall("obj.callMethod", args, retRegister, true)
		self:freeRegister(selfRegister)
		if borrowed then
			self:freeRegister(payloadRegister)
		end
		return retRegister
	end

	if expression.kind == "call_member" then
		if expression.member == "length" then
			error("length is not callable")
		end

		if expression.receiver.kind == "local_ref" and expression.member == nil then
			error("Unsupported call on local_ref receiver")
		end

		local receiverRegister = self:emitExpression(expression.receiver)
		local payloadRegister, borrowed = self:buildArgPayload(expression.arguments)
		local args = {
			receiverRegister,
			expression.member,
		}
		if payloadRegister ~= nil then
			table.insert(args, payloadRegister)
		end
		local retRegister = nil
		if wantResult then
			retRegister = self:allocRegister()
		end
		self:emitSyscall("obj.callMethod", args, retRegister, true)
		self:freeRegister(receiverRegister)
		if borrowed then
			self:freeRegister(payloadRegister)
		end
		return retRegister
	end

	error("Unsupported MT# call expression kind " .. tostring(expression.kind))
end

function ProgramEmitter:emitExpression(expression)
	if expression.kind == "literal" then
		local target = self:allocRegister()
		self:emit("LOADK", {
			a = target,
			b = expression.value,
		})
		return target
	end

	if expression.kind == "nil" then
		local target = self:allocRegister()
		self:emit("LOADK", {
			a = target,
			b = nil,
		})
		return target
	end

	if expression.kind == "local_ref" then
		return self:loadVariable(expression.name)
	end

	if expression.kind == "self_ref" then
		return self:loadVariable("self")
	end

	if expression.kind == "field_ref" then
		local selfRegister = self:loadVariable("self")
		local resultRegister = self:allocRegister()
		self:emitSyscall("obj.get", { selfRegister, expression.name }, resultRegister, true)
		self:freeRegister(selfRegister)
		return resultRegister
	end

	if expression.kind == "member_ref" then
		if expression.member == "length" and expression.object.kind == "local_ref" then
			return self:emitCallBySyscall("value.len", { expression.object }, true)
		end
		local objectRegister = self:emitExpression(expression.object)
		local resultRegister = self:allocRegister()
		self:emitSyscall("obj.get", { objectRegister, expression.member }, resultRegister, true)
		self:freeRegister(objectRegister)
		return resultRegister
	end

	if expression.kind == "unary" and expression.operator == "-" then
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
	end

	if expression.kind == "binary" and (expression.operator == "+" or expression.operator == "-" or expression.operator == "*" or expression.operator == "/") then
		local leftRegister = self:emitExpression(expression.left)
		local rightRegister = self:emitExpression(expression.right)
		local opName = ({
			["+"] = "ADD",
			["-"] = "SUB",
			["*"] = "MUL",
			["/"] = "DIV",
		})[expression.operator]
		self:emit(opName, {
			a = leftRegister,
			b = leftRegister,
			c = rightRegister,
		})
		self:freeRegister(rightRegister)
		return leftRegister
	end

	if string.sub(expression.kind or "", 1, 5) == "call_" then
		return self:emitCallExpression(expression, true)
	end

	if expression.kind == "new_object" then
		local modulePathRegister = self:allocRegister()
		self:emitSyscall("proc.modulePath", {}, modulePathRegister, false)
		local resultRegister = self:allocRegister()
		self:emitSyscall("obj.new", { expression.targetType, modulePathRegister }, resultRegister, false)
		self:freeRegister(modulePathRegister)
		return resultRegister
	end

	if expression.kind == "symbol_ref" then
		if #(expression.path or {}) == 1 then
			return self:loadVariable(expression.path[1])
		end
		error("Unsupported MT# symbol reference for executable emission: " .. table.concat(expression.path or {}, "."))
	end

	error("Unsupported MT# expression for executable emission: " .. tostring(expression.kind))
end

function ProgramEmitter:emitCondition(expression, falseLabel)
	if expression.kind == "binary" and ({
		["=="] = true,
		["!="] = true,
		[">"] = true,
		[">="] = true,
		["<"] = true,
		["<="] = true,
	})[expression.operator] then
		local leftRegister = self:emitExpression(expression.left)
		local rightRegister = self:emitExpression(expression.right)
		self:emit("CMP", {
			a = leftRegister,
			b = rightRegister,
		})
		self:emit("JMPIF", {
			condition = ({
				["=="] = "ne",
				["!="] = "eq",
				[">"] = "le",
				[">="] = "lt",
				["<"] = "ge",
				["<="] = "gt",
			})[expression.operator],
			target = falseLabel,
		})
		self:freeRegister(leftRegister)
		self:freeRegister(rightRegister)
		return
	end

	local register = self:emitExpression(expression)
	self:emit("CMP", {
		a = register,
		b = false,
	})
	self:emit("JMPIF", {
		condition = "eq",
		target = falseLabel,
	})
	self:freeRegister(register)
end

function ProgramEmitter:emitStatement(statement, context)
	context = context or {}

	if statement.kind == "declare" then
		self:ensureVariable(statement.name, nil)
		if statement.initializer then
			local register = self:emitExpression(statement.initializer)
			self:storeRegister(register, statement.name)
			self:freeRegister(register)
		end
		return
	end

	if statement.kind == "assign" then
		local register = self:emitExpression(statement.value)
		if statement.target.kind == "local_ref" then
			self:storeRegister(register, statement.target.name)
		elseif statement.target.kind == "symbol_ref" and #(statement.target.path or {}) == 1 then
			self:storeRegister(register, statement.target.path[1])
		elseif statement.target.kind == "field_ref" then
			local selfRegister = self:loadVariable("self")
			self:emitSyscall("obj.set", { selfRegister, statement.target.name, register }, selfRegister, true)
			self:freeRegister(selfRegister)
		elseif statement.target.kind == "member_ref" then
			local objectRegister = self:emitExpression(statement.target.object)
			self:emitSyscall("obj.set", { objectRegister, statement.target.member, register }, objectRegister, true)
			self:freeRegister(objectRegister)
		else
			error("Unsupported assignment target for executable emission")
		end
		self:freeRegister(register)
		return
	end

	if statement.kind == "expression" then
		local result = self:emitExpression(statement.expression)
		self:freeRegister(result)
		return
	end

	if statement.kind == "return" then
		if self.activeTryContext and self.activeTryContext.finallyLabel then
			if statement.expression then
				local register = self:emitExpression(statement.expression)
				self:storeRegister(register, self.activeTryContext.flowValueName)
				self:freeRegister(register)
			else
				self:storeConstant(nil, self.activeTryContext.flowValueName)
			end
			self:storeConstant(1, self.activeTryContext.flowKindName)
			self:emit("JMP", {
				target = self.activeTryContext.finallyLabel,
			})
			return
		end

		if self.kind == "library-export" then
			if statement.expression then
				local register = self:emitExpression(statement.expression)
				self:emitSyscall("lib.return", { register }, nil, false)
				self:freeRegister(register)
			else
				self:emitSyscall("lib.return", { nil }, nil, false)
			end
			self:emit("HALT")
			return
		end

		if statement.expression then
			local register = self:emitExpression(statement.expression)
			self:emitSyscall("exit", { register }, nil, false)
			self:freeRegister(register)
		else
			self:emitSyscall("exit", { 0 }, nil, false)
		end
		self:emit("HALT")
		return
	end

	if statement.kind == "if" then
		local falseLabel = self:newLabel("if_false")
		local endLabel = self:newLabel("if_end")
		self:emitCondition(statement.condition, falseLabel)
		for _, nested in ipairs(statement.thenBody) do
			self:emitStatement(nested, context)
		end
		if statement.elseBody and #statement.elseBody > 0 then
			self:emit("JMP", {
				target = endLabel,
			})
		end
		self:placeLabel(falseLabel)
		if statement.elseBody and #statement.elseBody > 0 then
			for _, nested in ipairs(statement.elseBody) do
				self:emitStatement(nested, context)
			end
			self:placeLabel(endLabel)
		end
		return
	end

	if statement.kind == "while" then
		local loopLabel = self:newLabel("while_loop")
		local endLabel = self:newLabel("while_end")
		self:placeLabel(loopLabel)
		self:emitCondition(statement.condition, endLabel)
		for _, nested in ipairs(statement.body) do
			self:emitStatement(nested, {
				breakLabel = endLabel,
				continueLabel = loopLabel,
			})
		end
		self:emit("JMP", {
			target = loopLabel,
		})
		self:placeLabel(endLabel)
		return
	end

	if statement.kind == "break" then
		if self.activeTryContext and self.activeTryContext.finallyLabel then
			assert(self.activeTryContext.breakLabel, "break used outside a loop")
			self:storeConstant(2, self.activeTryContext.flowKindName)
			self:emit("JMP", {
				target = self.activeTryContext.finallyLabel,
			})
			return
		end
		assert(context.breakLabel, "break used outside a loop")
		self:emit("JMP", {
			target = context.breakLabel,
		})
		return
	end

	if statement.kind == "continue" then
		if self.activeTryContext and self.activeTryContext.finallyLabel then
			assert(self.activeTryContext.continueLabel, "continue used outside a loop")
			self:storeConstant(3, self.activeTryContext.flowKindName)
			self:emit("JMP", {
				target = self.activeTryContext.finallyLabel,
			})
			return
		end
		assert(context.continueLabel, "continue used outside a loop")
		self:emit("JMP", {
			target = context.continueLabel,
		})
		return
	end

	if statement.kind == "try" then
		local outerTryContext = self.activeTryContext
		local catchLabel = self:newLabel("try_catch")
		local finallyLabel = self:newLabel("try_finally")
		local endLabel = self:newLabel("try_end")
		local unhandledLabel = self:newLabel("try_unhandled")
		local flowKindName = self:newLabel("flow_kind")
		local flowValueName = self:newLabel("flow_value")

		self:ensureVariable(flowKindName, 0)
		self:ensureVariable(flowValueName, nil)
		self:storeConstant(0, flowKindName)

		self.activeTryContext = {
			exceptionLabel = catchLabel,
			finallyLabel = finallyLabel,
			flowKindName = flowKindName,
			flowValueName = flowValueName,
			breakLabel = context.breakLabel,
			continueLabel = context.continueLabel,
		}
		for _, nested in ipairs(statement.tryBody or {}) do
			self:emitStatement(nested, context)
		end
		self.activeTryContext = outerTryContext
		self:emit("JMP", {
			target = finallyLabel,
		})

		self:placeLabel(catchLabel)
		if #(statement.catches or {}) > 0 then
			for index, catchClause in ipairs(statement.catches) do
				local nextCatchLabel = self:newLabel("try_catch_next")
				local exceptionRegister = self:allocRegister()
				local matchRegister = self:allocRegister()
				self:emitSyscall("exc.peek", {}, exceptionRegister, false)
				self:emitSyscall("exc.match", { exceptionRegister, catchClause.exceptionType }, matchRegister, false)
				self:emit("CMP", {
					a = matchRegister,
					b = true,
				})
				self:emit("JMPIF", {
					condition = "ne",
					target = nextCatchLabel,
				})
				self:freeRegister(matchRegister)
				self:freeRegister(exceptionRegister)

				if catchClause.bindingName and catchClause.bindingName ~= "" then
					self:ensureVariable(catchClause.bindingName, nil)
					local takenRegister = self:allocRegister()
					self:emitSyscall("exc.take", {}, takenRegister, false)
					self:storeRegister(takenRegister, catchClause.bindingName)
					self:freeRegister(takenRegister)
				else
					self:emitSyscall("exc.clear", {}, nil, false)
				end

				self.activeTryContext = {
					exceptionLabel = finallyLabel,
					finallyLabel = finallyLabel,
					flowKindName = flowKindName,
					flowValueName = flowValueName,
					breakLabel = context.breakLabel,
					continueLabel = context.continueLabel,
				}
				for _, nested in ipairs(catchClause.body or {}) do
					self:emitStatement(nested, context)
				end
				self.activeTryContext = outerTryContext
				self:emit("JMP", {
					target = finallyLabel,
				})
				self:placeLabel(nextCatchLabel)
			end
		end

		self:placeLabel(finallyLabel)
		self.activeTryContext = outerTryContext or {
			exceptionLabel = unhandledLabel,
		}
		for _, nested in ipairs(statement.finallyBody or {}) do
			self:emitStatement(nested, context)
		end
		self.activeTryContext = outerTryContext

		local hasExceptionRegister = self:allocRegister()
		self:emitSyscall("exc.has", {}, hasExceptionRegister, false)
		self:emit("CMP", {
			a = hasExceptionRegister,
			b = true,
		})
		if outerTryContext and outerTryContext.exceptionLabel then
			self:emit("JMPIF", {
				condition = "eq",
				target = outerTryContext.exceptionLabel,
			})
		else
			self:emit("JMPIF", {
				condition = "eq",
				target = unhandledLabel,
			})
		end
		self:freeRegister(hasExceptionRegister)

		local flowKindRegister = self:loadVariable(flowKindName)
		self:emit("CMP", {
			a = flowKindRegister,
			b = 1,
		})
		local notReturnLabel = self:newLabel("flow_not_return")
		self:emit("JMPIF", {
			condition = "ne",
			target = notReturnLabel,
		})
		self:freeRegister(flowKindRegister)

		local returnValueRegister = self:loadVariable(flowValueName)
		if self.kind == "library-export" then
			self:emitSyscall("lib.return", { returnValueRegister }, nil, false)
		else
			self:emitSyscall("exit", { returnValueRegister }, nil, false)
		end
		self:freeRegister(returnValueRegister)
		self:emit("HALT")
		self:placeLabel(notReturnLabel)

		local breakKindRegister = self:loadVariable(flowKindName)
		self:emit("CMP", {
			a = breakKindRegister,
			b = 2,
		})
		local notBreakLabel = self:newLabel("flow_not_break")
		self:emit("JMPIF", {
			condition = "ne",
			target = notBreakLabel,
		})
		self:freeRegister(breakKindRegister)
		if context.breakLabel then
			self:emit("JMP", {
				target = context.breakLabel,
			})
		end
		self:placeLabel(notBreakLabel)

		local continueKindRegister = self:loadVariable(flowKindName)
		self:emit("CMP", {
			a = continueKindRegister,
			b = 3,
		})
		local notContinueLabel = self:newLabel("flow_not_continue")
		self:emit("JMPIF", {
			condition = "ne",
			target = notContinueLabel,
		})
		self:freeRegister(continueKindRegister)
		if context.continueLabel then
			self:emit("JMP", {
				target = context.continueLabel,
			})
		end
		self:placeLabel(notContinueLabel)

		self:emit("JMP", {
			target = endLabel,
		})

		self:placeLabel(unhandledLabel)
		self:emitSyscall("exc.raisePending", {}, nil, true)
		self:emit("HALT")
		self:placeLabel(endLabel)
		-- Anchor the end label so normal control flow never jumps past the image.
		self:emit("NOP")
		self.activeTryContext = outerTryContext
		return
	end

	if statement.kind == "throw" then
		local exceptionRegister = self:emitExpression(statement.expression)
		self:emitSyscall("exc.throw", { exceptionRegister }, nil, false)
		self:freeRegister(exceptionRegister)
		if self.activeTryContext and self.activeTryContext.exceptionLabel then
			self:emit("JMP", {
				target = self.activeTryContext.exceptionLabel,
			})
		else
			self:emitSyscall("exc.raisePending", {}, nil, true)
			self:emit("HALT")
		end
		return
	end

	error("Unsupported MT# statement for executable emission: " .. tostring(statement.kind))
end

function ProgramEmitter:emitParameterSetup(irFunction)
	local parameterIndexShift = 0
	if irFunction.isConstructor then
		self:ensureVariable("self", nil)
		local modulePathRegister = self:allocRegister()
		self:emit("SYSCALL", {
			name = "proc.modulePath",
			args = {},
			ret = modulePathRegister,
		})
		local selfRegister = self:allocRegister()
		self:emit("SYSCALL", {
			name = "obj.new",
			args = { shortTypeName(irFunction.ownerType), modulePathRegister },
			ret = selfRegister,
		})
		self:storeRegister(selfRegister, "self")
		self:freeRegister(selfRegister)
		self:freeRegister(modulePathRegister)
		parameterIndexShift = 1
	end

	for index, parameter in ipairs(irFunction.parameters) do
		self:ensureVariable(parameter.name, nil)
		if parameter.name == "self" then
			if not irFunction.isConstructor then
				local register = self:emitProcArg(1)
				self:storeRegister(register, parameter.name)
				self:freeRegister(register)
			end
		elseif index == 1 and parameterIndexShift == 0 and type(parameter.parameterType) == "string" and parameter.parameterType:sub(-2) == "[]" then
			self:emit("STORE", {
				a = "R2",
				b = dataRef(self.variables[parameter.name]),
			})
		else
			local register = self:emitProcArg(index - parameterIndexShift)
			self:storeRegister(register, parameter.name)
			self:freeRegister(register)
		end
	end
end

function ProgramEmitter:compileFunction(irFunction, metadata)
	self:emitParameterSetup(irFunction)
	for _, statement in ipairs(irFunction.body) do
		self:emitStatement(statement)
	end
	if #self.code == 0 or self.code[#self.code].op ~= "HALT" then
		if self.kind == "library-export" then
			if irFunction.isConstructor then
				local selfRegister = self:loadVariable("self")
				self:emit("SYSCALL", {
					name = "lib.return",
					args = { selfRegister },
				})
				self:freeRegister(selfRegister)
			else
				self:emit("SYSCALL", {
					name = "lib.return",
					args = { nil },
				})
			end
		else
			self:emit("SYSCALL", {
				name = "exit",
				args = { 0 },
			})
		end
		self:emit("HALT")
	end
	self:resolveLabels()
	return newExecutable({
		name = self.name,
		kind = self.kind,
		stackSize = self.stackSize,
		entryPoint = 0,
		code = self.code,
		constants = {},
		data = self.data,
		metadata = metadata,
	})
end

function ImageEmitter.emit(irModule, options)
	options = options or {}

	local warnings = {}
	local function pushWarnings(list)
		for _, warning in ipairs(list or {}) do
			table.insert(warnings, warning)
		end
	end

	if irModule.targetKind == "program" then
		local entryFunction = irModule.functionMap[irModule.entryPoint]
		assert(entryFunction, "Missing IR entry point " .. tostring(irModule.entryPoint))
		local emitter = ProgramEmitter.new({
			name = options.name or irModule.name,
			kind = "program",
			stackSize = options.stackSize or 128,
		})
		local image = emitter:compileFunction(entryFunction, {
			compiler = "MentuxSharp.ImageEmitter",
			language = "MT#",
			namespace = irModule.namespace,
			targetKind = irModule.targetKind,
			entryPoint = irModule.entryPoint,
			functionCount = #irModule.functions,
		})
		pushWarnings(emitter.warnings)
		return {
			image = image,
			warnings = warnings,
		}
	end

	if irModule.targetKind == "library" then
		local exports = {}
		for exportName, functionName in pairs(irModule.exports) do
			local irFunction = irModule.functionMap[functionName]
			assert(irFunction, "Missing exported IR function " .. tostring(functionName))
			local emitter = ProgramEmitter.new({
				name = string.format("%s::%s", options.name or irModule.name, exportName),
				kind = "library-export",
				stackSize = options.stackSize or 128,
			})
			local ok, compiledOrError = pcall(function()
				return emitter:compileFunction(irFunction, {
					compiler = "MentuxSharp.ImageEmitter",
					language = "MT#",
					namespace = irModule.namespace,
					targetKind = irModule.targetKind,
					exportName = exportName,
					functionName = functionName,
				})
			end)
			assert(ok, string.format("Failed to emit library export %s: %s", exportName, tostring(compiledOrError)))
			exports[exportName] = compiledOrError
			pushWarnings(emitter.warnings)
		end
		return {
			image = newLibrary({
				name = options.name or irModule.name,
				kind = "library",
				exports = exports,
				metadata = {
					compiler = "MentuxSharp.ImageEmitter",
					language = "MT#",
					namespace = irModule.namespace,
					sharpNamespace = irModule.namespace,
					sharpPublicTypes = (function()
						local names = {}
						for _, typeInfo in ipairs(irModule.types or {}) do
							table.insert(names, tostring(typeInfo.name))
						end
						table.sort(names)
						return names
					end)(),
					targetKind = irModule.targetKind,
					functionCount = #irModule.functions,
					exportCount = (function()
						local count = 0
						for _ in pairs(exports) do
							count += 1
						end
						return count
					end)(),
				},
			}),
			warnings = warnings,
		}
	end

	if irModule.targetKind == "module" then
		local exports = {}
		for _, irFunction in ipairs(irModule.functions) do
			if irFunction.ownerType then
				local exportName = methodExportName(irFunction)
				local emitter = ProgramEmitter.new({
					name = string.format("%s::%s", options.name or irModule.name, exportName),
					kind = "library-export",
					moduleKind = "module",
					exportName = exportName,
					stackSize = options.stackSize or 128,
				})
				local ok, compiledOrError = pcall(function()
					return emitter:compileFunction(irFunction, {
						compiler = "MentuxSharp.ImageEmitter",
						language = "MT#",
						namespace = irModule.namespace,
						targetKind = irModule.targetKind,
						exportName = exportName,
						functionName = irFunction.fullName,
						ownerType = irFunction.ownerType,
					})
				end)
				assert(ok, string.format("Failed to emit module export %s: %s", exportName, tostring(compiledOrError)))
				exports[exportName] = compiledOrError
				pushWarnings(emitter.warnings)
			end
		end

		return {
			image = newLibrary({
				name = options.name or irModule.name,
				kind = "module",
				exports = exports,
				metadata = {
					compiler = "MentuxSharp.ImageEmitter",
					language = "MT#",
					namespace = irModule.namespace,
					sharpNamespace = irModule.namespace,
					sharpPublicTypes = (function()
						local names = {}
						for _, typeInfo in ipairs(irModule.types or {}) do
							table.insert(names, tostring(typeInfo.name))
						end
						table.sort(names)
						return names
					end)(),
					targetKind = irModule.targetKind,
					functionCount = #irModule.functions,
					typeCount = #irModule.types,
				},
			}),
			warnings = warnings,
		}
	end

	return {
		image = newLibrary({
			name = options.name or irModule.name,
			kind = "module",
			exports = {},
			metadata = {
				compiler = "MentuxSharp.ImageEmitter",
				language = "MT#",
				namespace = irModule.namespace,
				targetKind = irModule.targetKind,
				functionCount = #irModule.functions,
				note = "Module image metadata only; executable emission for object-oriented MT# bodies is still partial.",
			},
		}),
		warnings = warnings,
	}
end

function ImageEmitter.describe(image)
	if image.magic == EXEC_MAGIC then
		return string.format(
			"Executable name=%s kind=%s code=%d data=%d",
			tostring(image.name),
			tostring(image.kind),
			#(image.code or {}),
			#(image.data or {})
		)
	end

	if image.magic == LIB_MAGIC then
		local exportNames = {}
		for exportName in pairs(image.exports or {}) do
			table.insert(exportNames, exportName)
		end
		table.sort(exportNames)
		return string.format(
			"Library name=%s kind=%s exports=%s",
			tostring(image.name),
			tostring(image.kind),
			listToText(exportNames)
		)
	end

	return tostring(image)
end

return ImageEmitter
