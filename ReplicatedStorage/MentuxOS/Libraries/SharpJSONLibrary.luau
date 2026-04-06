local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local SharpJSONLibrarySource = require(script.Parent:WaitForChild("SharpJSONLibrarySource"))

return MentuxScriptCompiler.compileLibrary(SharpJSONLibrarySource, {
	name = "sharp-libraries-json",
	stackSize = 192,
	libraryMetadata = {
		author = "MentuxOS",
		category = "sharp",
		summary = "MT# namespace library for Libraries.Json.",
		sharpNamespace = "Libraries.Json",
		sharpPublicTypes = { "Json" },
	},
	exportMetadata = {
		["Json.parse"] = {
			summary = "Parse JSON text into Mentux values.",
		},
		["Json.stringify"] = {
			summary = "Encode Mentux values into JSON text.",
		},
	},
})
