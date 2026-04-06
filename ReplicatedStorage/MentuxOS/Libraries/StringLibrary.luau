local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local StringLibrarySource = require(script.Parent:WaitForChild("StringLibrarySource"))

return MentuxScriptCompiler.compileLibrary(StringLibrarySource, {
	name = "mentux-string",
	stackSize = 192,
	libraryMetadata = {
		author = "MentuxOS",
		category = "stdlib",
		summary = "Guest string helpers built on Mentux VM primitives.",
	},
	exportMetadata = {
		charAt = {
			summary = "Return the character at a 1-based string index.",
		},
		concat = {
			summary = "Concatenate two values as text.",
		},
		substr = {
			summary = "Return a substring from a start index and optional length.",
		},
		split = {
			summary = "Split a string by a literal delimiter.",
		},
	},
})
