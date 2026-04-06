local Lowerer = {}

local function hasModifier(modifiers, target)
	for _, modifier in ipairs(modifiers or {}) do
		if modifier == target then
			return true
		end
	end
	return false
end

local function joinParts(parts)
	return table.concat(parts or {}, ".")
end

local function appendPath(parts, value)
	local clone = table.clone(parts or {})
	table.insert(clone, value)
	return clone
end

local function buildSharpLibraryReference(parts)
	return "sharp:" .. table.concat(parts or {}, ".")
end

local function typeToString(typeReference)
	if not typeReference then
		return "void"
	end

	local name = joinParts(typeReference.nameParts)
	if #typeReference.genericArguments > 0 then
		local renderedArguments = {}
		for _, argument in ipairs(typeReference.genericArguments) do
			table.insert(renderedArguments, typeToString(argument))
		end
		name ..= "<" .. table.concat(renderedArguments, ", ") .. ">"
	end
	if typeReference.isArray then
		name ..= "[]"
	end
	return name
end

local function newScope(parent)
	return {
		parent = parent,
		locals = {},
	}
end

local function declareLocal(scope, name)
	scope.locals[name] = true
end

local function hasLocal(scope, name)
	local current = scope
	while current do
		if current.locals[name] then
			return true
		end
		current = current.parent
	end
	return false
end

local function flattenSymbolPath(expression, scope)
	if expression.kind == "Identifier" then
		if expression.name == "this" or hasLocal(scope, expression.name) then
			return nil
		end
		return { expression.name }
	end
	if expression.kind == "MemberExpression" then
		local base = flattenSymbolPath(expression.object, scope)
		if base then
			table.insert(base, expression.member)
			return base
		end
	end
	return nil
end

local lowerStatement

local function lowerExpression(moduleState, expression, scope, ownerType)
	if expression.kind == "Literal" then
		if expression.literalType == "null" then
			return { kind = "nil" }
		end
		return {
			kind = "literal",
			literalType = expression.literalType,
			value = expression.value,
		}
	end

	if expression.kind == "InterpolatedStringExpression" then
		local parts = {}
		for _, segment in ipairs(expression.segments or {}) do
			table.insert(parts, segment.value)
		end
		return {
			kind = "literal",
			literalType = "string",
			value = table.concat(parts),
		}
	end

	if expression.kind == "Identifier" then
		if expression.name == "this" then
			return { kind = "self_ref" }
		end
		if hasLocal(scope, expression.name) then
			return {
				kind = "local_ref",
				name = expression.name,
			}
		end
		return {
			kind = "symbol_ref",
			path = { expression.name },
		}
	end

	if expression.kind == "MemberExpression" then
		local flattened = flattenSymbolPath(expression, scope)
		if flattened then
			return {
				kind = "symbol_ref",
				path = flattened,
			}
		end

		local object = lowerExpression(moduleState, expression.object, scope, ownerType)
		if object.kind == "self_ref" then
			return {
				kind = "field_ref",
				name = expression.member,
				ownerType = ownerType,
			}
		end
		return {
			kind = "member_ref",
			object = object,
			member = expression.member,
		}
	end

	if expression.kind == "UnaryExpression" then
		return {
			kind = "unary",
			operator = expression.operator,
			argument = lowerExpression(moduleState, expression.argument, scope, ownerType),
		}
	end

	if expression.kind == "BinaryExpression" then
		return {
			kind = "binary",
			operator = expression.operator,
			left = lowerExpression(moduleState, expression.left, scope, ownerType),
			right = lowerExpression(moduleState, expression.right, scope, ownerType),
		}
	end

	if expression.kind == "ArrayLiteralExpression" then
		local elements = {}
		for _, element in ipairs(expression.elements) do
			table.insert(elements, lowerExpression(moduleState, element, scope, ownerType))
		end
		return {
			kind = "array",
			elements = elements,
		}
	end

	if expression.kind == "ObjectLiteralExpression" then
		local properties = {}
		for _, property in ipairs(expression.properties) do
			table.insert(properties, {
				key = property.key,
				value = lowerExpression(moduleState, property.value, scope, ownerType),
			})
		end
		return {
			kind = "object",
			properties = properties,
		}
	end

	if expression.kind == "NewExpression" then
		local arguments = {}
		for _, argument in ipairs(expression.arguments) do
			table.insert(arguments, lowerExpression(moduleState, argument, scope, ownerType))
		end
		return {
			kind = "new_object",
			targetType = typeToString(expression.targetType),
			arguments = arguments,
		}
	end

	if expression.kind == "AssignmentExpression" then
		return {
			kind = "binary",
			operator = expression.operator,
			left = lowerExpression(moduleState, expression.target, scope, ownerType),
			right = lowerExpression(moduleState, expression.value, scope, ownerType),
		}
	end

	if expression.kind == "CallExpression" then
		local arguments = {}
		for _, argument in ipairs(expression.arguments) do
			table.insert(arguments, lowerExpression(moduleState, argument, scope, ownerType))
		end

		local calleePath = flattenSymbolPath(expression.callee, scope)
		if calleePath then
			local alias = calleePath[1]
		if moduleState.libraryAliases[alias] and #calleePath >= 2 then
			return {
				kind = "call_library",
				alias = alias,
				libraryPath = moduleState.libraryAliases[alias],
				exportName = calleePath[#calleePath],
				arguments = arguments,
			}
		end
		if moduleState.sharpAliases[alias] and #calleePath >= 2 then
			return {
				kind = "call_library",
				alias = alias,
				libraryPath = moduleState.sharpAliases[alias],
				exportName = table.concat(calleePath, "."),
				arguments = arguments,
			}
		end
		if moduleState.embeddedAliases[alias] and #calleePath >= 2 then
			return {
				kind = "call_embedded",
				alias = alias,
					sourcePath = moduleState.embeddedAliases[alias],
					member = calleePath[#calleePath],
					arguments = arguments,
				}
			end
			return {
				kind = "call_symbol",
				path = calleePath,
				arguments = arguments,
				sharpNamespaces = table.clone(moduleState.sharpNamespaces),
			}
		end

		if expression.callee.kind == "MemberExpression" then
			local loweredReceiver = lowerExpression(moduleState, expression.callee.object, scope, ownerType)
			if loweredReceiver.kind == "self_ref" then
				return {
					kind = "call_self_method",
					ownerType = ownerType,
					member = expression.callee.member,
					arguments = arguments,
				}
			end
			return {
				kind = "call_member",
				receiver = loweredReceiver,
				member = expression.callee.member,
				arguments = arguments,
			}
		end

		return {
			kind = "call_member",
			receiver = lowerExpression(moduleState, expression.callee, scope, ownerType),
			member = nil,
			arguments = arguments,
		}
	end

	error("Unsupported AST expression for IR lowering: " .. tostring(expression.kind))
end

local function tryLowerFileReadGuard(moduleState, statement, scope, ownerType)
	if statement.finallyBlock ~= nil then
		return nil
	end
	if #statement.catches ~= 1 then
		return nil
	end
	if #statement.tryBlock.statements < 1 then
		return nil
	end

	local firstStatement = statement.tryBlock.statements[1]
	if firstStatement.kind ~= "ExpressionStatement" or firstStatement.expression.kind ~= "AssignmentExpression" then
		return nil
	end

	local assignedValue = firstStatement.expression.value
	if assignedValue.kind ~= "CallExpression" then
		return nil
	end

	local flattened = flattenSymbolPath(assignedValue.callee, scope)
	if not flattened or table.concat(flattened, ".") ~= "File.read" then
		return nil
	end

	local condition = {
		kind = "call_symbol",
		path = { "File", "exists" },
		arguments = {},
	}
	for _, argument in ipairs(assignedValue.arguments or {}) do
		table.insert(condition.arguments, lowerExpression(moduleState, argument, scope, ownerType))
	end

	local thenBody = {}
	for _, nested in ipairs(statement.tryBlock.statements) do
		lowerStatement(moduleState, nested, newScope(scope), ownerType, thenBody)
	end

	local elseBody = {}
	for _, nested in ipairs(statement.catches[1].body.statements) do
		lowerStatement(moduleState, nested, newScope(scope), ownerType, elseBody)
	end

	return {
		kind = "if",
		condition = condition,
		thenBody = thenBody,
		elseBody = elseBody,
	}
end

lowerStatement = function(moduleState, statement, scope, ownerType, sink)
	if statement.kind == "VariableDeclaration" then
		declareLocal(scope, statement.name)
		table.insert(sink, {
			kind = "declare",
			bindingKind = statement.bindingKind,
			name = statement.name,
			typeAnnotation = typeToString(statement.typeAnnotation),
			initializer = statement.initializer and lowerExpression(moduleState, statement.initializer, scope, ownerType) or nil,
		})
		return
	end

	if statement.kind == "ExpressionStatement" then
		if statement.expression.kind == "AssignmentExpression" then
			table.insert(sink, {
				kind = "assign",
				target = lowerExpression(moduleState, statement.expression.target, scope, ownerType),
				value = lowerExpression(moduleState, statement.expression.value, scope, ownerType),
				operator = statement.expression.operator,
			})
			return
		end
		table.insert(sink, {
			kind = "expression",
			expression = lowerExpression(moduleState, statement.expression, scope, ownerType),
		})
		return
	end

	if statement.kind == "ReturnStatement" then
		table.insert(sink, {
			kind = "return",
			expression = statement.expression and lowerExpression(moduleState, statement.expression, scope, ownerType) or nil,
		})
		return
	end

	if statement.kind == "ThrowStatement" then
		table.insert(sink, {
			kind = "throw",
			expression = lowerExpression(moduleState, statement.expression, scope, ownerType),
		})
		return
	end

	if statement.kind == "BreakStatement" then
		table.insert(sink, { kind = "break" })
		return
	end

	if statement.kind == "ContinueStatement" then
		table.insert(sink, { kind = "continue" })
		return
	end

	if statement.kind == "IfStatement" then
		local thenBody = {}
		local elseBody = {}
		for _, nested in ipairs(statement.thenBody.statements) do
			lowerStatement(moduleState, nested, newScope(scope), ownerType, thenBody)
		end
		if statement.elseBody then
			for _, nested in ipairs(statement.elseBody.statements) do
				lowerStatement(moduleState, nested, newScope(scope), ownerType, elseBody)
			end
		end
		table.insert(sink, {
			kind = "if",
			condition = lowerExpression(moduleState, statement.condition, scope, ownerType),
			thenBody = thenBody,
			elseBody = elseBody,
		})
		return
	end

	if statement.kind == "WhileStatement" then
		local body = {}
		for _, nested in ipairs(statement.body.statements) do
			lowerStatement(moduleState, nested, newScope(scope), ownerType, body)
		end
		table.insert(sink, {
			kind = "while",
			condition = lowerExpression(moduleState, statement.condition, scope, ownerType),
			body = body,
		})
		return
	end

	if statement.kind == "TryStatement" then
		local tryBody = {}
		local finallyBody = {}
		local catches = {}
		for _, nested in ipairs(statement.tryBlock.statements) do
			lowerStatement(moduleState, nested, newScope(scope), ownerType, tryBody)
		end
		for _, catchClause in ipairs(statement.catches) do
			local catchScope = newScope(scope)
			declareLocal(catchScope, catchClause.bindingName)
			local catchBody = {}
			for _, nested in ipairs(catchClause.body.statements) do
				lowerStatement(moduleState, nested, catchScope, ownerType, catchBody)
			end
			table.insert(catches, {
				exceptionType = typeToString(catchClause.exceptionType),
				bindingName = catchClause.bindingName,
				body = catchBody,
			})
		end
		if statement.finallyBlock then
			for _, nested in ipairs(statement.finallyBlock.statements) do
				lowerStatement(moduleState, nested, newScope(scope), ownerType, finallyBody)
			end
		end
		table.insert(sink, {
			kind = "try",
			tryBody = tryBody,
			catches = catches,
			finallyBody = finallyBody,
		})
		return
	end

	error("Unsupported AST statement for IR lowering: " .. tostring(statement.kind))
end

local function lowerFunctionBody(moduleState, bodyNode, parameters, ownerType)
	local scope = newScope(nil)
	for _, parameter in ipairs(parameters) do
		declareLocal(scope, parameter.name)
	end

	local statements = {}
	if bodyNode.kind == "BlockStatement" then
		for _, statement in ipairs(bodyNode.statements) do
			lowerStatement(moduleState, statement, scope, ownerType, statements)
		end
	else
		table.insert(statements, {
			kind = "return",
			expression = lowerExpression(moduleState, bodyNode, scope, ownerType),
		})
	end

	local locals = {}
	for name in pairs(scope.locals) do
		table.insert(locals, name)
	end
	table.sort(locals)
	return statements, locals
end

local function lowerParameters(parameters, implicitSelf)
	local lowered = {}
	if implicitSelf then
		table.insert(lowered, {
			name = "self",
			parameterType = implicitSelf,
		})
	end
	for _, parameter in ipairs(parameters or {}) do
		table.insert(lowered, {
			name = parameter.name,
			parameterType = typeToString(parameter.parameterType),
			defaultValue = parameter.defaultValue,
		})
	end
	return lowered
end

local function pushFunction(module, irFunction)
	table.insert(module.functions, irFunction)
	module.functionMap[irFunction.fullName] = irFunction
	if irFunction.isExported then
		module.exports[irFunction.name] = irFunction.fullName
	end
	if not module.entryPoint and irFunction.name == "Main" and irFunction.isStatic then
		module.entryPoint = irFunction.fullName
	end
end

local function lowerClass(moduleState, module, declaration)
	local fullTypeName = joinParts(appendPath(module.namespaceParts, declaration.name))
	local irType = {
		kind = "Type",
		name = declaration.name,
		fullName = fullTypeName,
		typeKind = "class",
		fields = {},
		properties = {},
		methods = {},
		constructors = {},
		modifiers = declaration.modifiers,
		baseTypes = declaration.baseTypes,
	}

	for _, member in ipairs(declaration.members) do
		if member.kind == "FieldDeclaration" then
			table.insert(irType.fields, {
				name = member.name,
				typeAnnotation = typeToString(member.typeAnnotation),
				modifiers = member.modifiers,
				initializer = member.initializer and lowerExpression(moduleState, member.initializer, newScope(nil), fullTypeName) or nil,
			})
		elseif member.kind == "PropertyDeclaration" then
			local backingFieldName = "__prop_" .. member.name
			table.insert(irType.fields, {
				name = backingFieldName,
				typeAnnotation = typeToString(member.propertyType),
				modifiers = { "private" },
				initializer = nil,
			})
			table.insert(irType.properties, {
				name = member.name,
				propertyType = typeToString(member.propertyType),
				modifiers = member.modifiers,
				backingField = backingFieldName,
			})
		elseif member.kind == "MethodDeclaration" then
			local isStatic = hasModifier(member.modifiers, "static")
			local parameters = lowerParameters(member.parameters, not isStatic and fullTypeName or nil)
			local body, locals = lowerFunctionBody(moduleState, member.body, parameters, fullTypeName)
			local irFunction = {
				kind = "Function",
				name = member.name,
				fullName = fullTypeName .. "." .. member.name,
				ownerType = fullTypeName,
				returnType = typeToString(member.returnType),
				parameters = parameters,
				locals = locals,
				body = body,
				modifiers = member.modifiers,
				isStatic = isStatic,
				isConstructor = false,
				isExported = member.isExported,
			}
			table.insert(irType.methods, irFunction.fullName)
			pushFunction(module, irFunction)
		elseif member.kind == "ConstructorDeclaration" then
			local parameters = lowerParameters(member.parameters, fullTypeName)
			local body, locals = lowerFunctionBody(moduleState, member.body, parameters, fullTypeName)
			local irFunction = {
				kind = "Function",
				name = ".ctor",
				fullName = fullTypeName .. ".ctor",
				ownerType = fullTypeName,
				returnType = fullTypeName,
				parameters = parameters,
				locals = locals,
				body = body,
				modifiers = member.modifiers,
				isStatic = false,
				isConstructor = true,
				isExported = false,
			}
			table.insert(irType.constructors, irFunction.fullName)
			pushFunction(module, irFunction)
		end
	end

	table.insert(module.types, irType)
end

function Lowerer.lower(ast, options)
	options = options or {}

	local namespaceParts = ast.namespace and ast.namespace.nameParts or {}
	local moduleState = {
		libraryAliases = {},
		embeddedAliases = {},
		sharpAliases = {},
		sharpNamespaces = {},
	}

	local module = {
		kind = "IRModule",
		name = options.name or (#namespaceParts > 0 and namespaceParts[#namespaceParts] or "Anonymous"),
		namespace = joinParts(namespaceParts),
		namespaceParts = namespaceParts,
		targetKind = options.targetKind or "auto",
		imports = {
			namespaces = {},
			libraries = {},
			sharp = {},
		},
		embeds = {},
		types = {},
		functions = {},
		functionMap = {},
		exports = {},
		entryPoint = nil,
		metadata = {
			language = "MT#",
			stage = "ir",
		},
	}

	for _, usingDirective in ipairs(ast.usings) do
		if usingDirective.mode == "namespace" then
			local namespaceName = joinParts(usingDirective.target)
			table.insert(module.imports.namespaces, namespaceName)
			table.insert(module.imports.sharp, {
				alias = nil,
				namespace = namespaceName,
				libraryPath = buildSharpLibraryReference(usingDirective.target),
			})
			table.insert(moduleState.sharpNamespaces, namespaceName)
		elseif usingDirective.mode == "alias" then
			local namespaceName = joinParts(usingDirective.target)
			table.insert(module.imports.namespaces, namespaceName)
			table.insert(module.imports.sharp, {
				alias = usingDirective.alias,
				namespace = namespaceName,
				libraryPath = buildSharpLibraryReference(usingDirective.target),
			})
			moduleState.sharpAliases[usingDirective.alias] = buildSharpLibraryReference(usingDirective.target)
		elseif usingDirective.mode == "mxl" then
			module.imports.libraries[usingDirective.alias] = usingDirective.target
			moduleState.libraryAliases[usingDirective.alias] = usingDirective.target
		end
	end

	for _, embedDirective in ipairs(ast.embeds) do
		module.embeds[embedDirective.alias] = embedDirective.sourcePath
		moduleState.embeddedAliases[embedDirective.alias] = embedDirective.sourcePath
	end

	for _, declaration in ipairs(ast.declarations) do
		if declaration.kind == "ClassDeclaration" then
			lowerClass(moduleState, module, declaration)
		elseif declaration.kind == "FunctionDeclaration" then
			local parameters = lowerParameters(declaration.parameters, nil)
			local body, locals = lowerFunctionBody(moduleState, declaration.body, parameters, nil)
			local fullName = module.namespace ~= "" and (module.namespace .. "." .. declaration.name) or declaration.name
			pushFunction(module, {
				kind = "Function",
				name = declaration.name,
				fullName = fullName,
				ownerType = nil,
				returnType = typeToString(declaration.returnType),
				parameters = parameters,
				locals = locals,
				body = body,
				modifiers = declaration.modifiers,
				isStatic = true,
				isConstructor = false,
				isExported = hasModifier(declaration.modifiers, "export"),
			})
		end
	end

	if module.targetKind == "auto" then
		if module.entryPoint then
			module.targetKind = "program"
		elseif next(module.exports) ~= nil then
			module.targetKind = "library"
		else
			module.targetKind = "module"
		end
	end

	return module
end

return Lowerer
