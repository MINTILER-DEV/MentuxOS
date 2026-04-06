local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local SharpSystemStringLibrarySource = require(script.Parent:WaitForChild("SharpSystemStringLibrarySource"))

return MentuxScriptCompiler.compileLibrary(SharpSystemStringLibrarySource, {
	name = "sharp-system-string",
	stackSize = 192,
	libraryMetadata = {
		author = "MentuxOS",
		category = "sharp",
		summary = "MT# namespace library for System.String.",
		sharpNamespace = "System.String",
		sharpPublicTypes = { "String" },
	},
})
