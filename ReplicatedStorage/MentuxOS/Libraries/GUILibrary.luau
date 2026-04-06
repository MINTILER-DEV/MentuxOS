local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local GUILibrarySource = require(script.Parent:WaitForChild("GUILibrarySource"))

return MentuxScriptCompiler.compileLibrary(GUILibrarySource, {
	name = "mentux-gui",
	stackSize = 256,
	libraryMetadata = {
		author = "MentuxOS",
		category = "ui",
		summary = "Guest GUI wrapper library built on primitive Mentux GUI syscalls.",
	},
})
