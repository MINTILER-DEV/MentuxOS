local AstSpec = require(script.Parent:WaitForChild("AstSpec"))
local Tokenizer = require(script.Parent:WaitForChild("Tokenizer"))

local Parser = {}
Parser.__index = Parser

local MODIFIERS = {
	public = true,
	private = true,
	protected = true,
	static = true,
	abstract = true,
	export = true,
	async = true,
}

local PRECEDENCE = {
	["="] = 1,
	["+="] = 1,
	["-="] = 1,
	["*="] = 1,
	["/="] = 1,
	["||"] = 2,
	["&&"] = 3,
	["=="] = 4,
	["!="] = 4,
	["<"] = 5,
	["<="] = 5,
	[">"] = 5,
	[">="] = 5,
	["+"] = 6,
	["-"] = 6,
	["*"] = 7,
	["/"] = 7,
	["%"] = 7,
}

local ASSIGNMENT_OPERATORS = {
	["="] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
}

local function parseError(token, message)
	error(string.format("%s at %d:%d near %s", message, token.line or 0, token.column or 0, tostring(token.lexeme or token.value)))
end

local function node(kind, fields)
	fields = fields or {}
	fields.kind = kind
	return fields
end

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
	local current = self:peek()
	self.index += 1
	return current
end

function Parser:match(kind, value)
	local current = self:peek()
	if current.kind == kind and (value == nil or current.value == value) then
		self:advance()
		return current
	end
	return nil
end

function Parser:matchKeyword(value)
	return self:match("keyword", value)
end

function Parser:matchSymbol(value)
	return self:match("symbol", value)
end

function Parser:expect(kind, value, label)
	local current = self:peek()
	if current.kind ~= kind or (value ~= nil and current.value ~= value) then
		parseError(current, label or string.format("Expected %s %s", tostring(kind), tostring(value)))
	end
	return self:advance()
end

function Parser:expectIdentifier(label)
	local current = self:peek()
	if current.kind ~= "identifier" and not (current.kind == "keyword" and (current.value == "this" or current.value == "base")) then
		parseError(current, label or "Expected identifier")
	end
	return self:advance()
end

function Parser:parseQualifiedName()
	local parts = { self:expectIdentifier("Expected qualified name part").value }
	while self:matchSymbol(".") do
		table.insert(parts, self:expectIdentifier("Expected qualified name part").value)
	end
	return parts
end

function Parser:parseModifiers()
	local modifiers = {}
	while true do
		local current = self:peek()
		if current.kind == "keyword" and MODIFIERS[current.value] then
			table.insert(modifiers, self:advance().value)
		else
			break
		end
	end
	return modifiers
end

function Parser:parseTypeReference()
	local nameParts = self:parseQualifiedName()
	local genericArguments = {}
	local isArray = false

	if self:matchSymbol("<") then
		repeat
			table.insert(genericArguments, self:parseTypeReference())
		until not self:matchSymbol(",")
		self:expect("symbol", ">", "Expected > to close generic argument list")
	end

	if self:matchSymbol("[") then
		self:expect("symbol", "]", "Expected ] after array type")
		isArray = true
	end

	return node("TypeReference", {
		nameParts = nameParts,
		genericArguments = genericArguments,
		isArray = isArray,
	})
end

function Parser:parseParameter()
	local parameterType = self:parseTypeReference()
	local name = self:expectIdentifier("Expected parameter name").value
	local defaultValue = nil
	if self:matchSymbol("=") then
		defaultValue = self:parseExpression()
	end
	return node("Parameter", {
		name = name,
		parameterType = parameterType,
		defaultValue = defaultValue,
	})
end

function Parser:parseParameterList()
	self:expect("symbol", "(", "Expected (")
	local parameters = {}
	if not self:matchSymbol(")") then
		repeat
			table.insert(parameters, self:parseParameter())
		until not self:matchSymbol(",")
		self:expect("symbol", ")", "Expected )")
	end
	return parameters
end

function Parser:parseNamespaceDeclaration()
	self:expect("keyword", "namespace", "Expected namespace")
	local nameParts = self:parseQualifiedName()
	self:expect("symbol", ";", "Expected ; after namespace declaration")
	return node("NamespaceDeclaration", {
		nameParts = nameParts,
	})
end

function Parser:parseUsingDirective()
	self:expect("keyword", "using", "Expected using")

	if self:matchKeyword("mxl") then
		local alias = self:expectIdentifier("Expected mxl alias").value
		self:expect("symbol", "=", "Expected = in mxl using")
		local pathToken = self:expect("string", nil, "Expected mxl path string")
		self:expect("symbol", ";", "Expected ; after using")
		return node("UsingDirective", {
			mode = "mxl",
			alias = alias,
			target = pathToken.value,
		})
	end

	local firstIdentifier = self:expectIdentifier("Expected using target or alias")
	if self:matchSymbol("=") then
		local targetParts = self:parseQualifiedName()
		self:expect("symbol", ";", "Expected ; after using alias")
		return node("UsingDirective", {
			mode = "alias",
			alias = firstIdentifier.value,
			target = targetParts,
		})
	end

	local parts = { firstIdentifier.value }
	while self:matchSymbol(".") do
		table.insert(parts, self:expectIdentifier("Expected qualified using name").value)
	end
	self:expect("symbol", ";", "Expected ; after using directive")
	return node("UsingDirective", {
		mode = "namespace",
		alias = nil,
		target = parts,
	})
end

function Parser:parseEmbedDirective()
	self:expect("keyword", "embed", "Expected embed")
	self:expect("keyword", "mtx", "Expected mtx in embed directive")
	local alias = self:expectIdentifier("Expected embed alias").value
	self:expect("keyword", "from", "Expected from in embed directive")
	local sourcePath = self:expect("string", nil, "Expected embedded source path").value
	self:expect("symbol", ";", "Expected ; after embed directive")
	return node("EmbedDirective", {
		embedKind = "mtx",
		alias = alias,
		sourcePath = sourcePath,
	})
end

function Parser:parseBlock()
	self:expect("symbol", "{", "Expected {")
	local statements = {}
	while not self:matchSymbol("}") do
		table.insert(statements, self:parseStatement())
	end
	return node("BlockStatement", {
		statements = statements,
	})
end

function Parser:parseLiteral()
	local current = self:peek()
	if current.kind == "number" then
		self:advance()
		return node("Literal", { literalType = "number", value = current.value })
	end
	if current.kind == "string" then
		self:advance()
		return node("Literal", { literalType = "string", value = current.value })
	end
	if current.kind == "interpolated_string" then
		self:advance()
		return node("InterpolatedStringExpression", {
			segments = {
				{ kind = "text", value = current.value },
			},
		})
	end
	if current.kind == "keyword" and (current.value == "true" or current.value == "false") then
		self:advance()
		return node("Literal", { literalType = "bool", value = current.value == "true" })
	end
	if current.kind == "keyword" and current.value == "null" then
		self:advance()
		return node("Literal", { literalType = "null", value = nil })
	end
	return nil
end

function Parser:parseArrayLiteral()
	self:expect("symbol", "[", "Expected [")
	local elements = {}
	if not self:matchSymbol("]") then
		repeat
			table.insert(elements, self:parseExpression())
		until not self:matchSymbol(",")
		self:expect("symbol", "]", "Expected ]")
	end
	return node("ArrayLiteralExpression", {
		elements = elements,
	})
end

function Parser:parseObjectLiteral()
	self:expect("symbol", "{", "Expected {")
	local properties = {}
	if not self:matchSymbol("}") then
		repeat
			local keyToken = self:expectIdentifier("Expected object property name")
			self:expect("symbol", ":", "Expected : after object property name")
			table.insert(properties, {
				key = keyToken.value,
				value = self:parseExpression(),
			})
		until not self:matchSymbol(",")
		self:expect("symbol", "}", "Expected }")
	end
	return node("ObjectLiteralExpression", {
		properties = properties,
	})
end

function Parser:parsePrimaryExpression()
	local literal = self:parseLiteral()
	if literal then
		return literal
	end

	if self:matchKeyword("new") then
		local targetType = self:parseTypeReference()
		local arguments = self:parseArgumentList()
		return node("NewExpression", {
			targetType = targetType,
			arguments = arguments,
		})
	end

	if self:matchSymbol("(") then
		local expression = self:parseExpression()
		self:expect("symbol", ")", "Expected )")
		return expression
	end

	if self:peek().kind == "symbol" and self:peek().value == "[" then
		return self:parseArrayLiteral()
	end

	if self:peek().kind == "symbol" and self:peek().value == "{" then
		return self:parseObjectLiteral()
	end

	local identifierToken = self:expectIdentifier("Expected expression")
	return node("Identifier", {
		name = identifierToken.value,
	})
end

function Parser:parseArgumentList()
	self:expect("symbol", "(", "Expected (")
	local arguments = {}
	if not self:matchSymbol(")") then
		repeat
			table.insert(arguments, self:parseExpression())
		until not self:matchSymbol(",")
		self:expect("symbol", ")", "Expected )")
	end
	return arguments
end

function Parser:parsePostfixExpression()
	local expression = self:parsePrimaryExpression()
	while true do
		if self:matchSymbol(".") then
			local member = self:expectIdentifier("Expected member name").value
			expression = node("MemberExpression", {
				object = expression,
				member = member,
				operator = ".",
			})
		elseif self:peek().kind == "symbol" and self:peek().value == "(" then
			expression = node("CallExpression", {
				callee = expression,
				arguments = self:parseArgumentList(),
				typeArguments = {},
			})
		elseif self:matchSymbol("[") then
			local indexExpression = self:parseExpression()
			self:expect("symbol", "]", "Expected ]")
			expression = node("IndexExpression", {
				object = expression,
				index = indexExpression,
			})
		else
			break
		end
	end
	return expression
end

function Parser:parseUnaryExpression()
	local current = self:peek()
	if (current.kind == "symbol" and (current.value == "!" or current.value == "-")) or (current.kind == "keyword" and current.value == "await") then
		self:advance()
		return node("UnaryExpression", {
			operator = current.value,
			argument = self:parseUnaryExpression(),
		})
	end
	return self:parsePostfixExpression()
end

function Parser:parseExpression(minPrecedence)
	minPrecedence = minPrecedence or 1
	local expression = self:parseUnaryExpression()

	while true do
		local operatorToken = self:peek()
		local precedence = PRECEDENCE[operatorToken.value]
		if operatorToken.kind ~= "symbol" or not precedence or precedence < minPrecedence then
			break
		end

		self:advance()
		local nextMinPrecedence = precedence + 1
		if ASSIGNMENT_OPERATORS[operatorToken.value] then
			nextMinPrecedence = precedence
		end

		local right = self:parseExpression(nextMinPrecedence)
		if ASSIGNMENT_OPERATORS[operatorToken.value] then
			expression = node("AssignmentExpression", {
				operator = operatorToken.value,
				target = expression,
				value = right,
			})
		else
			expression = node("BinaryExpression", {
				operator = operatorToken.value,
				left = expression,
				right = right,
			})
		end
	end

	return expression
end

function Parser:parseVariableDeclaration(bindingKind)
	self:expect("keyword", bindingKind, "Expected variable declaration")
	local typeAnnotation = nil
	local name = nil

	if bindingKind == "var" then
		name = self:expectIdentifier("Expected variable name").value
	else
		local checkpoint = self.index
		local ok, parsedType, parsedName = pcall(function()
			local localType = self:parseTypeReference()
			local localName = self:expectIdentifier("Expected variable name").value
			return localType, localName
		end)
		if ok then
			typeAnnotation = parsedType
			name = parsedName
		else
			self.index = checkpoint
			name = self:expectIdentifier("Expected variable name").value
		end
	end

	local initializer = nil
	if self:matchSymbol("=") then
		initializer = self:parseExpression()
	end
	self:expect("symbol", ";", "Expected ; after variable declaration")
	return node("VariableDeclaration", {
		bindingKind = bindingKind,
		name = name,
		typeAnnotation = typeAnnotation,
		initializer = initializer,
	})
end

function Parser:parseIfStatement()
	self:expect("keyword", "if", "Expected if")
	self:expect("symbol", "(", "Expected ( after if")
	local condition = self:parseExpression()
	self:expect("symbol", ")", "Expected ) after if condition")
	local thenBody = self:parseBlock()
	local elseBody = nil
	if self:matchKeyword("else") then
		if self:peek().kind == "keyword" and self:peek().value == "if" then
			elseBody = node("BlockStatement", {
				statements = { self:parseIfStatement() },
			})
		else
			elseBody = self:parseBlock()
		end
	end
	return node("IfStatement", {
		condition = condition,
		thenBody = thenBody,
		elseBody = elseBody,
	})
end

function Parser:parseWhileStatement()
	self:expect("keyword", "while", "Expected while")
	self:expect("symbol", "(", "Expected ( after while")
	local condition = self:parseExpression()
	self:expect("symbol", ")", "Expected ) after while condition")
	return node("WhileStatement", {
		condition = condition,
		body = self:parseBlock(),
	})
end

function Parser:parseForStatement()
	self:expect("keyword", "for", "Expected for")
	self:expect("symbol", "(", "Expected ( after for")
	local initializer = nil
	if not self:matchSymbol(";") then
		if self:peek().kind == "keyword" and (self:peek().value == "let" or self:peek().value == "var" or self:peek().value == "const") then
			initializer = self:parseVariableDeclaration(self:peek().value)
		else
			initializer = self:parseExpression()
			self:expect("symbol", ";", "Expected ; after for initializer")
		end
	end
	local condition = nil
	if not self:matchSymbol(";") then
		condition = self:parseExpression()
		self:expect("symbol", ";", "Expected ; after for condition")
	end
	local update = nil
	if not self:matchSymbol(")") then
		update = self:parseExpression()
		self:expect("symbol", ")", "Expected ) after for update")
	end
	return node("ForStatement", {
		initializer = initializer,
		condition = condition,
		update = update,
		body = self:parseBlock(),
	})
end

function Parser:parseForeachStatement()
	self:expect("keyword", "foreach", "Expected foreach")
	self:expect("symbol", "(", "Expected ( after foreach")
	self:expect("keyword", "let", "Expected let in foreach")
	local itemType = nil
	local itemName = nil
	if self:peek().kind == "identifier" and self:peek(1).kind == "identifier" then
		itemType = self:parseTypeReference()
		itemName = self:expectIdentifier("Expected foreach item name").value
	else
		itemName = self:expectIdentifier("Expected foreach item name").value
	end
	self:expect("keyword", "in", "Expected in in foreach")
	local collection = self:parseExpression()
	self:expect("symbol", ")", "Expected ) after foreach")
	return node("ForeachStatement", {
		itemName = itemName,
		itemType = itemType,
		collection = collection,
		body = self:parseBlock(),
	})
end

function Parser:parseSwitchStatement()
	self:expect("keyword", "switch", "Expected switch")
	self:expect("symbol", "(", "Expected ( after switch")
	local expression = self:parseExpression()
	self:expect("symbol", ")", "Expected ) after switch expression")
	self:expect("symbol", "{", "Expected { after switch")

	local cases = {}
	local defaultCase = nil
	while not self:matchSymbol("}") do
		if self:matchKeyword("case") then
			local caseExpression = self:parseExpression()
			self:expect("symbol", ":", "Expected : after case")
			local statements = {}
			while not (self:peek().kind == "keyword" and (self:peek().value == "case" or self:peek().value == "default")) and not (self:peek().kind == "symbol" and self:peek().value == "}") do
				table.insert(statements, self:parseStatement())
			end
			table.insert(cases, {
				expression = caseExpression,
				body = node("BlockStatement", { statements = statements }),
			})
		elseif self:matchKeyword("default") then
			self:expect("symbol", ":", "Expected : after default")
			local statements = {}
			while not (self:peek().kind == "symbol" and self:peek().value == "}") do
				table.insert(statements, self:parseStatement())
			end
			defaultCase = node("BlockStatement", { statements = statements })
		else
			parseError(self:peek(), "Expected case or default")
		end
	end

	return node("SwitchStatement", {
		expression = expression,
		cases = cases,
		defaultCase = defaultCase,
	})
end

function Parser:parseTryStatement()
	self:expect("keyword", "try", "Expected try")
	local tryBlock = self:parseBlock()
	local catches = {}
	while self:matchKeyword("catch") do
		self:expect("symbol", "(", "Expected ( after catch")
		local exceptionType = self:parseTypeReference()
		local bindingName = self:expectIdentifier("Expected catch binding name").value
		self:expect("symbol", ")", "Expected ) after catch binding")
		table.insert(catches, node("CatchClause", {
			exceptionType = exceptionType,
			bindingName = bindingName,
			body = self:parseBlock(),
		}))
	end
	local finallyBlock = nil
	if self:matchKeyword("finally") then
		finallyBlock = self:parseBlock()
	end
	return node("TryStatement", {
		tryBlock = tryBlock,
		catches = catches,
		finallyBlock = finallyBlock,
	})
end

function Parser:parseStatement()
	local current = self:peek()
	if current.kind == "symbol" and current.value == "{" then
		return self:parseBlock()
	end
	if current.kind == "keyword" and (current.value == "let" or current.value == "var" or current.value == "const") then
		return self:parseVariableDeclaration(current.value)
	end
	if current.kind == "keyword" and current.value == "if" then
		return self:parseIfStatement()
	end
	if current.kind == "keyword" and current.value == "while" then
		return self:parseWhileStatement()
	end
	if current.kind == "keyword" and current.value == "for" then
		return self:parseForStatement()
	end
	if current.kind == "keyword" and current.value == "foreach" then
		return self:parseForeachStatement()
	end
	if current.kind == "keyword" and current.value == "switch" then
		return self:parseSwitchStatement()
	end
	if current.kind == "keyword" and current.value == "try" then
		return self:parseTryStatement()
	end
	if current.kind == "keyword" and current.value == "throw" then
		self:advance()
		local expression = self:parseExpression()
		self:expect("symbol", ";", "Expected ; after throw")
		return node("ThrowStatement", {
			expression = expression,
		})
	end
	if current.kind == "keyword" and current.value == "return" then
		self:advance()
		local expression = nil
		if not self:matchSymbol(";") then
			expression = self:parseExpression()
			self:expect("symbol", ";", "Expected ; after return")
		end
		return node("ReturnStatement", {
			expression = expression,
		})
	end
	if current.kind == "keyword" and current.value == "break" then
		self:advance()
		self:expect("symbol", ";", "Expected ; after break")
		return node("BreakStatement")
	end
	if current.kind == "keyword" and current.value == "continue" then
		self:advance()
		self:expect("symbol", ";", "Expected ; after continue")
		return node("ContinueStatement")
	end

	local expression = self:parseExpression()
	self:expect("symbol", ";", "Expected ; after expression")
	return node("ExpressionStatement", {
		expression = expression,
	})
end

function Parser:parseAccessorDeclaration()
	local modifiers = self:parseModifiers()
	local accessorToken = self:peek()
	if accessorToken.kind ~= "identifier" and accessorToken.kind ~= "keyword" then
		parseError(accessorToken, "Expected accessor")
	end
	if accessorToken.value ~= "get" and accessorToken.value ~= "set" then
		parseError(accessorToken, "Expected get or set accessor")
	end
	self:advance()
	if self:matchSymbol(";") then
		return node("AccessorDeclaration", {
			accessorKind = accessorToken.value,
			body = nil,
			modifiers = modifiers,
			isAuto = true,
		})
	end
	return node("AccessorDeclaration", {
		accessorKind = accessorToken.value,
		body = self:parseBlock(),
		modifiers = modifiers,
		isAuto = false,
	})
end

function Parser:parseClassMember()
	local modifiers = self:parseModifiers()

	if self:matchKeyword("constructor") then
		local parameters = self:parseParameterList()
		local baseCall = nil
		if self:matchSymbol(":") then
			local baseTarget = self:expectIdentifier("Expected base constructor target").value
			local baseArguments = self:parseArgumentList()
			baseCall = {
				target = baseTarget,
				arguments = baseArguments,
			}
		end
		return node("ConstructorDeclaration", {
			parameters = parameters,
			body = self:parseBlock(),
			baseCall = baseCall,
			modifiers = modifiers,
		})
	end

	local memberType = self:parseTypeReference()
	local memberName = self:expectIdentifier("Expected member name").value

	if self:peek().kind == "symbol" and self:peek().value == "(" then
		local parameters = self:parseParameterList()
		local body = nil
		local isExpressionBody = false
		if self:matchSymbol("=>") then
			body = self:parseExpression()
			self:expect("symbol", ";", "Expected ; after expression-bodied method")
			isExpressionBody = true
		else
			body = self:parseBlock()
		end
		return node("MethodDeclaration", {
			name = memberName,
			returnType = memberType,
			parameters = parameters,
			body = body,
			modifiers = modifiers,
			typeParameters = {},
			isExported = table.find(modifiers, "export") ~= nil,
			isExpressionBody = isExpressionBody,
		})
	end

	if self:peek().kind == "symbol" and self:peek().value == "{" then
		self:advance()
		local accessors = {}
		while not self:matchSymbol("}") do
			table.insert(accessors, self:parseAccessorDeclaration())
		end
		local getAccessor = nil
		local setAccessor = nil
		for _, accessor in ipairs(accessors) do
			if accessor.accessorKind == "get" then
				getAccessor = accessor
			elseif accessor.accessorKind == "set" then
				setAccessor = accessor
			end
		end
		return node("PropertyDeclaration", {
			name = memberName,
			propertyType = memberType,
			modifiers = modifiers,
			getAccessor = getAccessor,
			setAccessor = setAccessor,
		})
	end

	local initializer = nil
	if self:matchSymbol("=") then
		initializer = self:parseExpression()
	end
	self:expect("symbol", ";", "Expected ; after field declaration")
	return node("FieldDeclaration", {
		name = memberName,
		typeAnnotation = memberType,
		initializer = initializer,
		modifiers = modifiers,
	})
end

function Parser:parseClassDeclaration(modifiers)
	self:expect("keyword", "class", "Expected class")
	local name = self:expectIdentifier("Expected class name").value
	local baseTypes = {}
	if self:matchSymbol(":") then
		repeat
			table.insert(baseTypes, self:parseTypeReference())
		until not self:matchSymbol(",")
	end
	self:expect("symbol", "{", "Expected { after class declaration")
	local members = {}
	while not self:matchSymbol("}") do
		table.insert(members, self:parseClassMember())
	end
	return node("ClassDeclaration", {
		name = name,
		modifiers = modifiers,
		baseTypes = baseTypes,
		members = members,
		typeParameters = {},
	})
end

function Parser:parseInterfaceDeclaration(modifiers)
	self:expect("keyword", "interface", "Expected interface")
	local name = self:expectIdentifier("Expected interface name").value
	local baseTypes = {}
	if self:matchSymbol(":") then
		repeat
			table.insert(baseTypes, self:parseTypeReference())
		until not self:matchSymbol(",")
	end
	self:expect("symbol", "{", "Expected { after interface declaration")
	local members = {}
	while not self:matchSymbol("}") do
		local memberModifiers = self:parseModifiers()
		local returnType = self:parseTypeReference()
		local memberName = self:expectIdentifier("Expected interface member name").value
		local parameters = self:parseParameterList()
		self:expect("symbol", ";", "Expected ; after interface member")
		table.insert(members, node("MethodDeclaration", {
			name = memberName,
			returnType = returnType,
			parameters = parameters,
			body = nil,
			modifiers = memberModifiers,
			typeParameters = {},
			isExported = table.find(memberModifiers, "export") ~= nil,
		}))
	end
	return node("InterfaceDeclaration", {
		name = name,
		modifiers = modifiers,
		baseTypes = baseTypes,
		members = members,
		typeParameters = {},
	})
end

function Parser:parseEnumDeclaration(modifiers)
	self:expect("keyword", "enum", "Expected enum")
	local name = self:expectIdentifier("Expected enum name").value
	self:expect("symbol", "{", "Expected { after enum")
	local members = {}
	if not self:matchSymbol("}") then
		repeat
			table.insert(members, self:expectIdentifier("Expected enum member").value)
		until not self:matchSymbol(",")
		self:expect("symbol", "}", "Expected } after enum members")
	end
	return node("EnumDeclaration", {
		name = name,
		members = members,
		modifiers = modifiers,
	})
end

function Parser:parseConstDeclaration(modifiers)
	self:expect("keyword", "const", "Expected const")
	local typeAnnotation = self:parseTypeReference()
	local name = self:expectIdentifier("Expected constant name").value
	self:expect("symbol", "=", "Expected = in const declaration")
	local value = self:parseExpression()
	self:expect("symbol", ";", "Expected ; after const declaration")
	return node("ConstDeclaration", {
		name = name,
		typeAnnotation = typeAnnotation,
		value = value,
		modifiers = modifiers,
	})
end

function Parser:parseFunctionDeclaration(modifiers)
	self:expect("keyword", "function", "Expected function")
	local returnType = self:parseTypeReference()
	local name = self:expectIdentifier("Expected function name").value
	local parameters = self:parseParameterList()
	local body = nil
	local isExpressionBody = false
	if self:matchSymbol("=>") then
		body = self:parseExpression()
		self:expect("symbol", ";", "Expected ; after expression-bodied function")
		isExpressionBody = true
	else
		body = self:parseBlock()
	end
	return node("FunctionDeclaration", {
		name = name,
		returnType = returnType,
		parameters = parameters,
		body = body,
		modifiers = modifiers,
		typeParameters = {},
		isExpressionBody = isExpressionBody,
	})
end

function Parser:parseDeclaration()
	local modifiers = self:parseModifiers()
	local current = self:peek()
	if current.kind == "keyword" and current.value == "const" then
		return self:parseConstDeclaration(modifiers)
	end
	if current.kind == "keyword" and current.value == "enum" then
		return self:parseEnumDeclaration(modifiers)
	end
	if current.kind == "keyword" and current.value == "class" then
		return self:parseClassDeclaration(modifiers)
	end
	if current.kind == "keyword" and current.value == "interface" then
		return self:parseInterfaceDeclaration(modifiers)
	end
	if current.kind == "keyword" and current.value == "function" then
		return self:parseFunctionDeclaration(modifiers)
	end
	parseError(current, "Expected declaration")
end

function Parser:parseSourceFile()
	local namespaceDeclaration = nil
	local usings = {}
	local embeds = {}
	local declarations = {}

	if self:peek().kind == "keyword" and self:peek().value == "namespace" then
		namespaceDeclaration = self:parseNamespaceDeclaration()
	end

	while self:peek().kind == "keyword" and self:peek().value == "using" do
		table.insert(usings, self:parseUsingDirective())
	end

	while self:peek().kind == "keyword" and self:peek().value == "embed" do
		table.insert(embeds, self:parseEmbedDirective())
	end

	while self:peek().kind ~= "eof" do
		table.insert(declarations, self:parseDeclaration())
	end

	self:expect("eof", "<eof>", "Expected end of file")
	return node(AstSpec.root.kind, {
		namespace = namespaceDeclaration,
		usings = usings,
		embeds = embeds,
		declarations = declarations,
	})
end

function Parser.parseTokens(tokens)
	return Parser.new(tokens):parseSourceFile()
end

function Parser.parse(source)
	return Parser.parseTokens(Tokenizer.tokenize(source))
end

return Parser
