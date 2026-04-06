local CodeGen = {}

local function renderPath(path)
	return table.concat(path or {}, ".")
end

local function newEmitter()
	return {
		instructions = {},
		labelCounter = 0,
	}
end

local function emit(state, op, payload)
	local instruction = payload or {}
	instruction.op = op
	table.insert(state.instructions, instruction)
end

local function newLabel(state, prefix)
	state.labelCounter += 1
	return string.format("%s_%d", prefix, state.labelCounter)
end

local function emitExpression(state, expression)
	if expression.kind == "literal" then
		emit(state, "PUSH_CONST", {
			value = expression.value,
			literalType = expression.literalType,
		})
		return
	end

	if expression.kind == "nil" then
		emit(state, "PUSH_NIL")
		return
	end

	if expression.kind == "local_ref" then
		emit(state, "LOAD_LOCAL", {
			name = expression.name,
		})
		return
	end

	if expression.kind == "self_ref" then
		emit(state, "LOAD_SELF")
		return
	end

	if expression.kind == "symbol_ref" then
		emit(state, "LOAD_SYMBOL", {
			path = renderPath(expression.path),
		})
		return
	end

	if expression.kind == "field_ref" then
		emit(state, "LOAD_FIELD", {
			name = expression.name,
			ownerType = expression.ownerType,
		})
		return
	end

	if expression.kind == "member_ref" then
		emitExpression(state, expression.object)
		emit(state, "LOAD_MEMBER", {
			member = expression.member,
		})
		return
	end

	if expression.kind == "unary" then
		emitExpression(state, expression.argument)
		emit(state, "UNARY", {
			operator = expression.operator,
		})
		return
	end

	if expression.kind == "binary" then
		emitExpression(state, expression.left)
		emitExpression(state, expression.right)
		emit(state, "BINARY", {
			operator = expression.operator,
		})
		return
	end

	if expression.kind == "array" then
		for _, element in ipairs(expression.elements) do
			emitExpression(state, element)
		end
		emit(state, "BUILD_ARRAY", {
			count = #expression.elements,
		})
		return
	end

	if expression.kind == "object" then
		local keys = {}
		for _, property in ipairs(expression.properties) do
			table.insert(keys, property.key)
			emitExpression(state, property.value)
		end
		emit(state, "BUILD_OBJECT", {
			keys = keys,
		})
		return
	end

	if expression.kind == "new_object" then
		for _, argument in ipairs(expression.arguments) do
			emitExpression(state, argument)
		end
		emit(state, "NEW_OBJECT", {
			targetType = expression.targetType,
			argc = #expression.arguments,
		})
		return
	end

	if expression.kind == "call_symbol" then
		for _, argument in ipairs(expression.arguments) do
			emitExpression(state, argument)
		end
		emit(state, "CALL_SYMBOL", {
			path = renderPath(expression.path),
			argc = #expression.arguments,
		})
		return
	end

	if expression.kind == "call_self_method" then
		for _, argument in ipairs(expression.arguments) do
			emitExpression(state, argument)
		end
		emit(state, "CALL_SELF_METHOD", {
			ownerType = expression.ownerType,
			member = expression.member,
			argc = #expression.arguments,
		})
		return
	end

	if expression.kind == "call_library" then
		for _, argument in ipairs(expression.arguments) do
			emitExpression(state, argument)
		end
		emit(state, "CALL_LIBRARY", {
			alias = expression.alias,
			libraryPath = expression.libraryPath,
			exportName = expression.exportName,
			argc = #expression.arguments,
		})
		return
	end

	if expression.kind == "call_embedded" then
		for _, argument in ipairs(expression.arguments) do
			emitExpression(state, argument)
		end
		emit(state, "CALL_EMBEDDED", {
			alias = expression.alias,
			sourcePath = expression.sourcePath,
			member = expression.member,
			argc = #expression.arguments,
		})
		return
	end

	if expression.kind == "call_member" then
		emitExpression(state, expression.receiver)
		for _, argument in ipairs(expression.arguments) do
			emitExpression(state, argument)
		end
		emit(state, "CALL_MEMBER", {
			member = expression.member,
			argc = #expression.arguments,
		})
		return
	end

	error("Unsupported IR expression for codegen: " .. tostring(expression.kind))
end

local function emitStore(state, target)
	if target.kind == "local_ref" then
		emit(state, "STORE_LOCAL", {
			name = target.name,
		})
	elseif target.kind == "field_ref" then
		emit(state, "STORE_FIELD", {
			name = target.name,
			ownerType = target.ownerType,
		})
	elseif target.kind == "member_ref" then
		emitExpression(state, target.object)
		emit(state, "STORE_MEMBER", {
			member = target.member,
		})
	else
		emit(state, "STORE_TARGET")
	end
end

local function emitBlock(state, statements, loopContext)
	loopContext = loopContext or {}

	for _, statement in ipairs(statements) do
		if statement.kind == "declare" then
			if statement.initializer then
				emitExpression(state, statement.initializer)
			else
				emit(state, "PUSH_NIL")
			end
			emit(state, "STORE_LOCAL", {
				name = statement.name,
				bindingKind = statement.bindingKind,
			})
		elseif statement.kind == "assign" then
			emitExpression(state, statement.value)
			emitStore(state, statement.target)
		elseif statement.kind == "expression" then
			emitExpression(state, statement.expression)
			emit(state, "POP")
		elseif statement.kind == "return" then
			if statement.expression then
				emitExpression(state, statement.expression)
			else
				emit(state, "PUSH_NIL")
			end
			emit(state, "RETURN")
		elseif statement.kind == "throw" then
			emitExpression(state, statement.expression)
			emit(state, "THROW")
		elseif statement.kind == "if" then
			local elseLabel = newLabel(state, "if_else")
			local endLabel = newLabel(state, "if_end")
			emitExpression(state, statement.condition)
			emit(state, "JUMP_IF_FALSE", {
				target = elseLabel,
			})
			emitBlock(state, statement.thenBody, loopContext)
			emit(state, "JUMP", {
				target = endLabel,
			})
			emit(state, "LABEL", { name = elseLabel })
			emitBlock(state, statement.elseBody or {}, loopContext)
			emit(state, "LABEL", { name = endLabel })
		elseif statement.kind == "while" then
			local startLabel = newLabel(state, "while_start")
			local endLabel = newLabel(state, "while_end")
			emit(state, "LABEL", { name = startLabel })
			emitExpression(state, statement.condition)
			emit(state, "JUMP_IF_FALSE", {
				target = endLabel,
			})
			emitBlock(state, statement.body, {
				breakTarget = endLabel,
				continueTarget = startLabel,
			})
			emit(state, "JUMP", {
				target = startLabel,
			})
			emit(state, "LABEL", { name = endLabel })
		elseif statement.kind == "try" then
			local endLabel = newLabel(state, "try_end")
			local finallyLabel = (#statement.finallyBody > 0) and newLabel(state, "try_finally") or nil
			local catchLabels = {}
			for index = 1, #statement.catches do
				catchLabels[index] = newLabel(state, "try_catch")
			end
			emit(state, "TRY_BEGIN", {
				catchTargets = catchLabels,
				finallyTarget = finallyLabel,
			})
			emitBlock(state, statement.tryBody, loopContext)
			emit(state, "TRY_END")
			emit(state, "JUMP", {
				target = finallyLabel or endLabel,
			})
			for index, catchClause in ipairs(statement.catches) do
				emit(state, "LABEL", { name = catchLabels[index] })
				emit(state, "CATCH_BEGIN", {
					exceptionType = catchClause.exceptionType,
					bindingName = catchClause.bindingName,
				})
				emitBlock(state, catchClause.body, loopContext)
				emit(state, "JUMP", {
					target = finallyLabel or endLabel,
				})
			end
			if finallyLabel then
				emit(state, "LABEL", { name = finallyLabel })
				emitBlock(state, statement.finallyBody, loopContext)
			end
			emit(state, "LABEL", { name = endLabel })
		elseif statement.kind == "break" then
			emit(state, "JUMP", {
				target = loopContext.breakTarget or "<invalid-break>",
			})
		elseif statement.kind == "continue" then
			emit(state, "JUMP", {
				target = loopContext.continueTarget or "<invalid-continue>",
			})
		else
			error("Unsupported IR statement for codegen: " .. tostring(statement.kind))
		end
	end
end

local function generateFunction(irFunction)
	local state = newEmitter()
	emit(state, "FUNC_BEGIN", {
		name = irFunction.fullName,
		returnType = irFunction.returnType,
		parameters = irFunction.parameters,
		locals = irFunction.locals,
	})
	emitBlock(state, irFunction.body)
	if #state.instructions == 0 or state.instructions[#state.instructions].op ~= "RETURN" then
		emit(state, "PUSH_NIL")
		emit(state, "RETURN")
	end
	return {
		name = irFunction.name,
		fullName = irFunction.fullName,
		ownerType = irFunction.ownerType,
		returnType = irFunction.returnType,
		parameters = irFunction.parameters,
		locals = irFunction.locals,
		instructions = state.instructions,
		modifiers = irFunction.modifiers,
	}
end

function CodeGen.generate(irModule, options)
	options = options or {}
	local functions = {}
	for _, irFunction in ipairs(irModule.functions) do
		table.insert(functions, generateFunction(irFunction))
	end

	return {
		format = "mentux-backend-plan",
		stage = "codegen",
		targetKind = irModule.targetKind,
		targetExtension = (irModule.targetKind == "library" or irModule.targetKind == "module") and ".mxl" or ".mtx",
		name = options.name or irModule.name,
		namespace = irModule.namespace,
		entryPoint = irModule.entryPoint,
		imports = irModule.imports,
		embeds = irModule.embeds,
		exports = irModule.exports,
		functions = functions,
		metadata = {
			sourceLanguage = "MT#",
			functionCount = #functions,
			typeCount = #irModule.types,
		},
	}
end

function CodeGen.renderListing(backend)
	local lines = {
		string.format("; target=%s name=%s", tostring(backend.targetKind), tostring(backend.name)),
	}

	if backend.entryPoint then
		table.insert(lines, "; entry=" .. backend.entryPoint)
	end

	for _, compiledFunction in ipairs(backend.functions) do
		table.insert(lines, "")
		table.insert(lines, "func " .. compiledFunction.fullName)
		for _, instruction in ipairs(compiledFunction.instructions) do
			local payload = {}
			for key, value in pairs(instruction) do
				if key ~= "op" then
					table.insert(payload, key .. "=" .. tostring(value))
				end
			end
			table.sort(payload)
			table.insert(lines, "  " .. instruction.op .. (#payload > 0 and (" " .. table.concat(payload, " ")) or ""))
		end
	end

	return table.concat(lines, "\n")
end

return CodeGen
