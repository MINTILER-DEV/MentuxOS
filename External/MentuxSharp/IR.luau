local IR = {}

IR.nodeKinds = {
	Module = {
		fields = {
			"name",
			"namespace",
			"targetKind",
			"imports",
			"embeds",
			"types",
			"functions",
			"exports",
			"entryPoint",
			"metadata",
		},
	},
	Type = {
		fields = {
			"name",
			"fullName",
			"kind",
			"fields",
			"properties",
			"methods",
			"constructors",
			"modifiers",
		},
	},
	Function = {
		fields = {
			"name",
			"fullName",
			"ownerType",
			"returnType",
			"parameters",
			"locals",
			"body",
			"modifiers",
			"isStatic",
			"isConstructor",
			"isExported",
		},
	},
	Statement = {
		kinds = {
			"declare",
			"assign",
			"expression",
			"if",
			"while",
			"try",
			"throw",
			"return",
			"break",
			"continue",
		},
	},
	Expression = {
		kinds = {
			"literal",
			"nil",
			"local_ref",
			"self_ref",
			"symbol_ref",
			"field_ref",
			"member_ref",
			"unary",
			"binary",
			"call_symbol",
			"call_member",
			"call_library",
			"call_embedded",
			"new_object",
			"array",
			"object",
		},
	},
}

IR.notes = {
	"The MT# IR is function-oriented and class-aware, but simplified enough for an early backend.",
	"Instance methods keep an implicit self model at the IR layer.",
	"Library and embedded MTX calls are made explicit during lowering so codegen does not need to guess call semantics.",
}

return IR
