local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local SharpSystemIOLibrarySource = require(script.Parent:WaitForChild("SharpSystemIOLibrarySource"))

return MentuxScriptCompiler.compileLibrary(SharpSystemIOLibrarySource, {
	name = "sharp-system-io",
	stackSize = 192,
	libraryMetadata = {
		author = "MentuxOS",
		category = "sharp",
		summary = "MT# namespace library for System.IO.",
		sharpNamespace = "System.IO",
		sharpPublicTypes = { "Directory", "File", "Path" },
	},
	exportMetadata = {
		["File.read"] = {
			summary = "Read a file relative to the current Mentux working directory.",
		},
		["File.write"] = {
			summary = "Write text to a file relative to the current Mentux working directory.",
		},
		["File.append"] = {
			summary = "Append text to a file relative to the current Mentux working directory.",
		},
		["File.exists"] = {
			summary = "Check whether a file exists.",
		},
		["File.statKind"] = {
			summary = "Get the Mentux VFS kind for a path.",
		},
		["Directory.list"] = {
			summary = "List directory contents.",
		},
		["Path.resolve"] = {
			summary = "Resolve a path against the current working directory.",
		},
	},
})
