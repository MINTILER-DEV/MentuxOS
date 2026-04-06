local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local JSONLibrarySource = require(script.Parent:WaitForChild("JSONLibrarySource"))

return MentuxScriptCompiler.compileLibrary(JSONLibrarySource, {
	name = "core-json",
	stackSize = 192,
	libraryMetadata = {
		author = "MentuxOS",
		category = "core",
		summary = "Compiled Mentux JSON helpers exposed through mxl exports.",
	},
	exportMetadata = {
		parse = {
			summary = "Parse JSON text into Mentux values.",
		},
		stringify = {
			summary = "Encode Mentux values into JSON text.",
		},
	},
})
