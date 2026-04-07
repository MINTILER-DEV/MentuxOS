local MentuxScriptCompiler = require(script.Parent.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local MtxDTLibrarySource = require(script.Parent:WaitForChild("MtxDTLibrarySource"))

return MentuxScriptCompiler.compileLibrary(MtxDTLibrarySource, {
	name = "mentux-mtxdt",
	stackSize = 256,
	libraryMetadata = {
		author = "MentuxOS",
		category = "network",
		summary = "Mentux-native virtual networking and web stack.",
		sharpNamespace = "Mentux.Web.MtxDT",
		sharpPublicTypes = { "Webpage", "Response", "Server", "Dns", "Client", "Socket", "Store" },
	},
})
