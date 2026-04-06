local GrammarSpec = {}

GrammarSpec.language = {
	name = "Mentux Sharp",
	shortName = "MT#",
	sourceExtension = ".msh",
	executableExtension = ".mtx",
	libraryExtension = ".mxl",
	status = "front-end prototype",
}

GrammarSpec.lexical = {
	comments = {
		line = "//",
		blockStart = "/*",
		blockEnd = "*/",
	},
	literals = {
		string = [["..."]],
		interpolatedString = [[$"...{expr}..."]],
		number = "integer | float",
		boolean = { "true", "false" },
		nilLiteral = "null",
	},
	identifier = {
		description = "Starts with a letter or underscore, then letters, digits, or underscores",
		pattern = "^[A-Za-z_][A-Za-z0-9_]*$",
	},
	qualifiedName = {
		description = "Dot-separated identifiers",
		example = "Apps.Productivity.Notepad",
	},
}

GrammarSpec.keywords = {
	"namespace",
	"using",
	"embed",
	"from",
	"mtx",
	"mxl",
	"class",
	"interface",
	"enum",
	"function",
	"constructor",
	"public",
	"private",
	"protected",
	"static",
	"abstract",
	"export",
	"const",
	"let",
	"var",
	"if",
	"else",
	"while",
	"for",
	"foreach",
	"in",
	"switch",
	"case",
	"default",
	"break",
	"continue",
	"return",
	"try",
	"catch",
	"finally",
	"throw",
	"new",
	"this",
	"base",
	"async",
	"await",
	"true",
	"false",
	"null",
}

GrammarSpec.precedence = {
	{ name = "assignment", operators = { "=", "+=", "-=", "*=", "/=" }, associativity = "right" },
	{ name = "logicalOr", operators = { "||" }, associativity = "left" },
	{ name = "logicalAnd", operators = { "&&" }, associativity = "left" },
	{ name = "equality", operators = { "==", "!=" }, associativity = "left" },
	{ name = "comparison", operators = { "<", "<=", ">", ">=" }, associativity = "left" },
	{ name = "term", operators = { "+", "-" }, associativity = "left" },
	{ name = "factor", operators = { "*", "/", "%" }, associativity = "left" },
	{ name = "unary", operators = { "!", "-", "await" }, associativity = "right" },
	{ name = "postfix", operators = { ".", "()", "[]", "++", "--" }, associativity = "left" },
}

GrammarSpec.topLevelOrder = {
	"namespaceDeclaration?",
	"usingDirective*",
	"embedDirective*",
	"declaration*",
}

GrammarSpec.ebnf = {
	sourceFile = [[
sourceFile
  ::= namespaceDeclaration? usingDirective* embedDirective* declaration*
]],

	namespaceDeclaration = [[
namespaceDeclaration
  ::= "namespace" qualifiedName ";"
]],

	usingDirective = [[
usingDirective
  ::= "using" qualifiedName ";"
   |  "using" identifier "=" qualifiedName ";"
   |  "using" "mxl" identifier "=" stringLiteral ";"
]],

	embedDirective = [[
embedDirective
  ::= "embed" "mtx" identifier "from" stringLiteral ";"
]],

	declaration = [[
declaration
  ::= constDeclaration
   |  enumDeclaration
   |  classDeclaration
   |  interfaceDeclaration
   |  functionDeclaration
]],

	classDeclaration = [[
classDeclaration
  ::= modifier* "class" identifier baseClause? "{" classMember* "}"

baseClause
  ::= ":" typeReference ("," typeReference)*
]],

	classMember = [[
classMember
  ::= fieldDeclaration
   |  methodDeclaration
   |  constructorDeclaration
   |  propertyDeclaration
]],

	functionDeclaration = [[
functionDeclaration
  ::= modifier* "function" typeReference identifier typeParameters? parameterList block
   |  modifier* "function" typeReference identifier typeParameters? parameterList "=>" expression ";"
]],

	propertyDeclaration = [[
propertyDeclaration
  ::= modifier* typeReference identifier "{"
        accessorDeclaration+
      "}"

accessorDeclaration
  ::= "get" block
   |  "set" block
   |  "get" ";"
   |  "set" ";"
]],

	statement = [[
statement
  ::= block
   |  variableDeclaration
   |  ifStatement
   |  whileStatement
   |  forStatement
   |  foreachStatement
   |  switchStatement
   |  tryStatement
   |  throwStatement
   |  returnStatement
   |  breakStatement
   |  continueStatement
   |  expressionStatement
]],

	expression = [[
expression
  ::= assignmentExpression

assignmentExpression
  ::= logicalOrExpression
   |  leftHandSide assignmentOperator assignmentExpression
]],
}

GrammarSpec.notes = {
	"MT# is intentionally class-first and namespace-first.",
	"MXL imports are explicit in the grammar because library calls are a first-class compile target.",
	"Embedded MTX references are treated as packaged external executables, not as normal namespaces.",
	"Exceptions are part of the surface syntax even if the initial lowering uses result checks under the hood.",
}

return GrammarSpec
