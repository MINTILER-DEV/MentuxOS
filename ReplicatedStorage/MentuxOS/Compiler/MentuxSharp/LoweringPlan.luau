local LoweringPlan = {}

LoweringPlan.phases = {
	{
		name = "tokenize",
		output = "Token[]",
		goals = {
			"Recognize MT# keywords, identifiers, qualified names, literals, and punctuation",
			"Preserve source locations for compiler diagnostics",
			"Tokenize interpolated strings into literal and expression segments",
		},
	},
	{
		name = "parse",
		output = "AST",
		goals = {
			"Build the node kinds described in AstSpec",
			"Respect the declaration order constraints from GrammarSpec",
			"Produce recoverable parse errors with line and column ranges",
		},
	},
	{
		name = "bind",
		output = "Bound AST / symbol tables",
		goals = {
			"Resolve namespace symbols, class members, and imports",
			"Bind mxl aliases to library references",
			"Bind embedded mtx aliases to packaged executable references",
		},
	},
	{
		name = "type-check",
		output = "Typed AST",
		goals = {
			"Validate field/property/method signatures",
			"Check exception catch types and constructor calls",
			"Resolve generic containers and method overload candidates",
		},
	},
	{
		name = "desugar",
		output = "Lowered AST",
		goals = {
			"Lower properties into getter/setter members or backing fields",
			"Lower foreach and switch into simpler control flow",
			"Lower string interpolation into concat chains or runtime helpers",
		},
	},
	{
		name = "exception-lowering",
		output = "Trap-aware lowered AST",
		goals = {
			"Represent try/catch/finally in a form the VM backend can support",
			"Map throw sites to runtime exception records",
			"Preserve catch ordering and finally semantics",
		},
	},
	{
		name = "backend-selection",
		output = ".mtx or .mxl plan",
		goals = {
			"Choose executable output when an entry point is present",
			"Choose library output when exported members are present",
			"Collect embedded mtx assets and referenced mxl dependencies",
		},
	},
	{
		name = "emit",
		output = "Mentux image",
		goals = {
			"Emit machine-code program bodies for functions and exports",
			"Emit metadata for classes, namespaces, and symbols",
			"Produce .mtx or .mxl images compatible with Mentux runtime loaders",
		},
	},
}

LoweringPlan.outputContracts = {
	mtx = {
		entryRequirements = {
			"At least one executable entry point such as Program.Main",
		},
		imageKind = "program",
	},
	mxl = {
		entryRequirements = {
			"One or more exported methods or functions",
		},
		imageKind = "library",
		exportRule = "Each export lowers to a callable machine-code body address or export thunk",
	},
}

LoweringPlan.semanticRules = {
	{
		rule = "using mxl Alias = \"/path/file.mxl\"",
		lowering = "Create a library alias symbol; member calls lower to lib.call(aliasPath, exportName, args)",
	},
	{
		rule = "embed mtx Tool from \"/path/tool.mtx\"",
		lowering = "Create an embedded executable symbol with path/name/exec/spawn surface",
	},
	{
		rule = "class members",
		lowering = "Early compiler may lower instance methods to static functions with explicit self parameter",
	},
	{
		rule = "exceptions",
		lowering = "Lower to runtime exception objects plus jump tables or result guards",
	},
}

LoweringPlan.initialImplementationCut = {
	scope = "design target for a first usable compiler",
	includes = {
		"namespace",
		"using",
		"using mxl",
		"embed mtx",
		"class",
		"fields",
		"methods",
		"constructors",
		"return",
		"if",
		"while",
		"try/catch/finally",
		"throw",
		".msh -> .mtx",
		".msh -> .mxl",
	},
	defers = {
		"full generics implementation",
		"async/await",
		"interfaces with complex variance",
		"overload resolution beyond simple signatures",
	},
}

return LoweringPlan
