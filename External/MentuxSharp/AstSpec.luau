local AstSpec = {}

AstSpec.root = {
	kind = "SourceFile",
	fields = {
		{ name = "namespace", type = "NamespaceDeclaration?" },
		{ name = "usings", type = "UsingDirective[]" },
		{ name = "embeds", type = "EmbedDirective[]" },
		{ name = "declarations", type = "Declaration[]" },
	},
}

AstSpec.nodeKinds = {
	SourceFile = {
		category = "root",
		fields = { "namespace", "usings", "embeds", "declarations" },
	},
	NamespaceDeclaration = {
		category = "top-level",
		fields = { "nameParts" },
	},
	UsingDirective = {
		category = "top-level",
		fields = { "mode", "alias", "target" },
		modes = { "namespace", "alias", "mxl" },
	},
	EmbedDirective = {
		category = "top-level",
		fields = { "embedKind", "alias", "sourcePath" },
		embedKinds = { "mtx" },
	},
	ConstDeclaration = {
		category = "declaration",
		fields = { "name", "typeAnnotation", "value", "modifiers" },
	},
	EnumDeclaration = {
		category = "declaration",
		fields = { "name", "members", "modifiers" },
	},
	ClassDeclaration = {
		category = "declaration",
		fields = { "name", "modifiers", "baseTypes", "members", "typeParameters" },
	},
	InterfaceDeclaration = {
		category = "declaration",
		fields = { "name", "modifiers", "baseTypes", "members", "typeParameters" },
	},
	FunctionDeclaration = {
		category = "declaration",
		fields = { "name", "returnType", "parameters", "body", "modifiers", "typeParameters", "isExpressionBody" },
	},
	FieldDeclaration = {
		category = "member",
		fields = { "name", "typeAnnotation", "initializer", "modifiers" },
	},
	MethodDeclaration = {
		category = "member",
		fields = { "name", "returnType", "parameters", "body", "modifiers", "typeParameters", "isExported" },
	},
	ConstructorDeclaration = {
		category = "member",
		fields = { "parameters", "body", "baseCall", "modifiers" },
	},
	PropertyDeclaration = {
		category = "member",
		fields = { "name", "propertyType", "modifiers", "getAccessor", "setAccessor" },
	},
	AccessorDeclaration = {
		category = "member",
		fields = { "accessorKind", "body", "modifiers", "isAuto" },
	},
	BlockStatement = {
		category = "statement",
		fields = { "statements" },
	},
	VariableDeclaration = {
		category = "statement",
		fields = { "bindingKind", "name", "typeAnnotation", "initializer" },
		bindingKinds = { "const", "let", "var" },
	},
	IfStatement = {
		category = "statement",
		fields = { "condition", "thenBody", "elseBody" },
	},
	WhileStatement = {
		category = "statement",
		fields = { "condition", "body" },
	},
	ForStatement = {
		category = "statement",
		fields = { "initializer", "condition", "update", "body" },
	},
	ForeachStatement = {
		category = "statement",
		fields = { "itemName", "itemType", "collection", "body" },
	},
	SwitchStatement = {
		category = "statement",
		fields = { "expression", "cases", "defaultCase" },
	},
	TryStatement = {
		category = "statement",
		fields = { "tryBlock", "catches", "finallyBlock" },
	},
	CatchClause = {
		category = "statement",
		fields = { "exceptionType", "bindingName", "body" },
	},
	ThrowStatement = {
		category = "statement",
		fields = { "expression" },
	},
	ReturnStatement = {
		category = "statement",
		fields = { "expression" },
	},
	BreakStatement = {
		category = "statement",
		fields = {},
	},
	ContinueStatement = {
		category = "statement",
		fields = {},
	},
	ExpressionStatement = {
		category = "statement",
		fields = { "expression" },
	},
	Identifier = {
		category = "expression",
		fields = { "name" },
	},
	QualifiedIdentifier = {
		category = "expression",
		fields = { "parts" },
	},
	Literal = {
		category = "expression",
		fields = { "literalType", "value" },
		literalTypes = { "string", "number", "bool", "null" },
	},
	InterpolatedStringExpression = {
		category = "expression",
		fields = { "segments" },
	},
	CallExpression = {
		category = "expression",
		fields = { "callee", "arguments", "typeArguments" },
	},
	MemberExpression = {
		category = "expression",
		fields = { "object", "member", "operator" },
	},
	IndexExpression = {
		category = "expression",
		fields = { "object", "index" },
	},
	NewExpression = {
		category = "expression",
		fields = { "targetType", "arguments" },
	},
	UnaryExpression = {
		category = "expression",
		fields = { "operator", "argument" },
	},
	BinaryExpression = {
		category = "expression",
		fields = { "operator", "left", "right" },
	},
	AssignmentExpression = {
		category = "expression",
		fields = { "operator", "target", "value" },
	},
	ArrayLiteralExpression = {
		category = "expression",
		fields = { "elements" },
	},
	ObjectLiteralExpression = {
		category = "expression",
		fields = { "properties" },
	},
	LambdaExpression = {
		category = "expression",
		fields = { "parameters", "body", "isExpressionBody" },
	},
	TypeReference = {
		category = "type",
		fields = { "nameParts", "genericArguments", "isArray" },
	},
	Parameter = {
		category = "type",
		fields = { "name", "parameterType", "defaultValue" },
	},
}

AstSpec.loweringViews = {
	symbolModel = {
		namespaces = "flat symbol table with qualified names",
		classes = "type symbols plus method/property member tables",
		embeds = "packaged executable symbols with special runtime wrappers",
		mxlImports = "library aliases resolved to explicit export call sites",
	},
	runtimeModel = {
		classes = "lower to records + namespaced functions in early compiler versions",
		exceptions = "lower to protected result flow / trap tables",
		properties = "lower to getter/setter methods or backing fields",
	},
}

AstSpec.notes = {
	"The AST is class-aware even if the first compiler lowers classes to simpler structures.",
	"Exported methods are the main bridge from .msh library source to .mxl compiled exports.",
	"Embedded MTX references should survive semantic analysis as special symbols, not plain strings.",
}

return AstSpec
