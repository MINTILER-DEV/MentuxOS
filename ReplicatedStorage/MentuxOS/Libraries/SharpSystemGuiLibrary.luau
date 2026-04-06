local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local SharpSystemGuiLibrarySource = require(script.Parent:WaitForChild("SharpSystemGuiLibrarySource"))

return MentuxScriptCompiler.compileLibrary(SharpSystemGuiLibrarySource, {
	name = "sharp-system-gui",
	stackSize = 224,
	libraryMetadata = {
		author = "MentuxOS",
		category = "sharp",
		summary = "MT# namespace library for System.Gui.",
		sharpNamespace = "System.Gui",
		sharpPublicTypes = { "Gui" },
	},
})
