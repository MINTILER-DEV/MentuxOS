local Assembler = require(script.Parent.Compiler:WaitForChild("Assembler"))
local MentuxSharp = require(script.Parent.Compiler:WaitForChild("MentuxSharp"))
local MentuxScriptCompiler = require(script.Parent.Compiler:WaitForChild("MentuxScriptCompiler"))
local BrowserScript = require(script.Parent.Programs:WaitForChild("BrowserScript"))
local CatScript = require(script.Parent.Programs:WaitForChild("CatScript"))
local CodeLauncherScript = require(script.Parent.Programs:WaitForChild("CodeLauncherScript"))
local CurlScript = require(script.Parent.Programs:WaitForChild("CurlScript"))
local FilesScript = require(script.Parent.Programs:WaitForChild("FilesScript"))
local GUIScript = require(script.Parent.Programs:WaitForChild("GUIScript"))
local HelloScript = require(script.Parent.Programs:WaitForChild("HelloScript"))
local InitScript = require(script.Parent.Programs:WaitForChild("InitScript"))
local JSONLibrary = require(script.Parent.Libraries:WaitForChild("JSONLibrary"))
local GUILibrary = require(script.Parent.Libraries:WaitForChild("GUILibrary"))
local KernelSource = require(script.Parent.Programs:WaitForChild("KernelSource"))
local MtxDTLibrary = require(script.Parent.Libraries:WaitForChild("MtxDTLibrary"))
local MtxDTHostScript = require(script.Parent.Programs:WaitForChild("MtxDTHostScript"))
local MTSumScript = require(script.Parent.Programs:WaitForChild("MTSumScript"))
local NotepadScript = require(script.Parent.Programs:WaitForChild("NotepadScript"))
local PingScript = require(script.Parent.Programs:WaitForChild("PingScript"))
local SharpJSONLibrary = require(script.Parent.Libraries:WaitForChild("SharpJSONLibrary"))
local SharpSystemGuiLibrary = require(script.Parent.Libraries:WaitForChild("SharpSystemGuiLibrary"))
local SharpSystemIOLibrary = require(script.Parent.Libraries:WaitForChild("SharpSystemIOLibrary"))
local SharpSystemStringLibrary = require(script.Parent.Libraries:WaitForChild("SharpSystemStringLibrary"))
local SettingsLauncherScript = require(script.Parent.Programs:WaitForChild("SettingsLauncherScript"))
local StringLibrary = require(script.Parent.Libraries:WaitForChild("StringLibrary"))
local MTSharpPrograms = require(script.Parent.Programs:WaitForChild("MTSharp"))
local UIMotionLibrary = require(script.Parent.Libraries:WaitForChild("UIMotionLibrary"))
local MCIScript = require(script.Parent.Programs:WaitForChild("MCIScript"))
local TerminalScript = require(script.Parent.Programs:WaitForChild("TerminalScript"))

local ExamplePrograms = {}
local MentuxSharpCompiler = MentuxSharp.Compiler

local function makeAppNode(image, title, taskbar, extraChildren)
	local children = {
		["main.mtx"] = {
			kind = "file",
			content = image,
		},
		["taskbar.json"] = {
			kind = "file",
			content = string.format('{"title":"%s","taskbar":%s}', title, taskbar and "true" or "false"),
		},
	}

	for name, child in pairs(extraChildren or {}) do
		children[name] = child
	end

	return {
		kind = "dir",
		children = children,
	}
end

function ExamplePrograms.buildKernelImage()
	return Assembler.assemble({
		source = KernelSource,
	})
end

function ExamplePrograms.buildHelloImage()
	return MentuxScriptCompiler.compile(HelloScript, {
		name = "hello-user",
		stackSize = 192,
		metadata = {
			displayName = "Hello",
			summary = "Example Mentux userland command that prints argv.",
			category = "demo",
		},
	})
end

function ExamplePrograms.buildCatImage()
	return MentuxScriptCompiler.compile(CatScript, {
		name = "mentux-cat",
		stackSize = 192,
		metadata = {
			displayName = "cat",
			summary = "Displays file contents or compiled file metadata.",
			category = "filesystem",
		},
	})
end

function ExamplePrograms.buildBrowserImage()
	return MentuxScriptCompiler.compile(BrowserScript, {
		name = "mentux-browser",
		stackSize = 512,
		metadata = {
			displayName = "browser",
			summary = "MtxDT browser for Mentux-native websites and live channels.",
			category = "network",
		},
	})
end

function ExamplePrograms.buildCodeLauncherImage()
	return MentuxScriptCompiler.compile(CodeLauncherScript, {
		name = "mentux-code-launcher",
		stackSize = 256,
		metadata = {
			displayName = "code",
			summary = "Launcher for the MT# code editor.",
			category = "editor",
		},
	})
end

function ExamplePrograms.buildInitImage()
	return MentuxScriptCompiler.compile(InitScript, {
		name = "mentux-init",
		stackSize = 192,
		metadata = {
			displayName = "init",
			summary = "Boot-time userland setup and session handoff.",
			category = "boot",
		},
	})
end

function ExamplePrograms.buildCurlImage()
	return MentuxScriptCompiler.compile(CurlScript, {
		name = "mentux-curl",
		stackSize = 224,
		metadata = {
			displayName = "curl",
			summary = "HTTP GET client over the Mentux server bridge.",
			category = "network",
		},
	})
end

function ExamplePrograms.buildMtxDTHostImage()
	return MentuxScriptCompiler.compile(MtxDTHostScript, {
		name = "mentux-mtxdt-host",
		stackSize = 224,
		metadata = {
			displayName = "mtxdthost",
			summary = "Registers the example MtxDT site and DNS records.",
			category = "network",
		},
	})
end

function ExamplePrograms.buildShellImage()
	return MentuxScriptCompiler.compile(MCIScript, {
		name = "mentux-command-interpreter",
		stackSize = 320,
		metadata = {
			displayName = "mci",
			summary = "Mentux command interpreter shell.",
			category = "shell",
		},
	})
end

function ExamplePrograms.buildPingImage()
	return MentuxScriptCompiler.compile(PingScript, {
		name = "mentux-ping",
		stackSize = 224,
		metadata = {
			displayName = "ping",
			summary = "Checks HTTP reachability and round-trip time.",
			category = "network",
		},
	})
end

function ExamplePrograms.buildGUIImage()
	return MentuxScriptCompiler.compile(GUIScript, {
		name = "mentux-gui",
		stackSize = 384,
		metadata = {
			displayName = "gui",
			summary = "Login and desktop session manager.",
			category = "session",
		},
	})
end

function ExamplePrograms.buildFilesImage()
	return MentuxScriptCompiler.compile(FilesScript, {
		name = "mentux-files",
		stackSize = 384,
		metadata = {
			displayName = "files",
			summary = "Filesystem browser and file preview app.",
			category = "filesystem",
		},
	})
end

function ExamplePrograms.buildNotepadImage()
	return MentuxScriptCompiler.compile(NotepadScript, {
		name = "mentux-notepad",
		stackSize = 384,
		metadata = {
			displayName = "notepad",
			summary = "Simple text editor for Mentux files.",
			category = "editor",
		},
	})
end

function ExamplePrograms.buildMTSumImage()
	return MentuxScriptCompiler.compile(MTSumScript, {
		name = "mentux-mtsum",
		stackSize = 256,
		metadata = {
			displayName = "mtsum",
			summary = "Shows full Mentux executable and library instruction summaries.",
			category = "inspect",
		},
	})
end

function ExamplePrograms.buildTerminalImage()
	return MentuxScriptCompiler.compile(TerminalScript, {
		name = "mentux-terminal",
		stackSize = 256,
		metadata = {
			displayName = "terminal",
			summary = "Terminal host app for the Mentux shell.",
			category = "terminal",
		},
	})
end

function ExamplePrograms.buildSettingsLauncherImage()
	return MentuxScriptCompiler.compile(SettingsLauncherScript, {
		name = "mentux-settings-launcher",
		stackSize = 224,
		metadata = {
			displayName = "settings",
			summary = "Launcher for the MT# Settings application module.",
			category = "system",
		},
	})
end

function ExamplePrograms.buildSettingsLibraryImage()
	return MentuxSharpCompiler.compileImage(MTSharpPrograms.SettingsApp, {
		name = "SettingsApp",
	})
end

function ExamplePrograms.buildCodeLibraryImage()
	return MentuxSharpCompiler.compileImage(MTSharpPrograms.CodeEditorApp, {
		name = "CodeEditorApp",
	})
end

function ExamplePrograms.buildMtxDTExampleSiteImage()
	return MentuxSharpCompiler.compileImage(MTSharpPrograms.MtxDTExampleSite, {
		name = "WebsiteTuxSite",
	})
end

function ExamplePrograms.createSystemDisk()
	return {
		kind = "dir",
		children = {
			boot = {
				kind = "dir",
				children = {
					["kernel.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildKernelImage(),
					},
					["init.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildInitImage(),
					},
				},
			},
			bin = {
				kind = "dir",
				children = {
					["gui.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildGUIImage(),
					},
					["mci.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildShellImage(),
					},
					["hello.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildHelloImage(),
					},
					["cat.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildCatImage(),
					},
					["mtsum.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildMTSumImage(),
					},
					["curl.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildCurlImage(),
					},
					["mtxdthost.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildMtxDTHostImage(),
					},
					["ping.mtx"] = {
						kind = "file",
						content = ExamplePrograms.buildPingImage(),
					},
				},
			},
			apps = {
				kind = "dir",
				children = {
					system = {
						kind = "dir",
						children = {
							terminal = makeAppNode(ExamplePrograms.buildTerminalImage(), "Terminal", true),
							files = makeAppNode(ExamplePrograms.buildFilesImage(), "Files", true),
							browser = makeAppNode(ExamplePrograms.buildBrowserImage(), "Browser", true),
							code = makeAppNode(ExamplePrograms.buildCodeLauncherImage(), "Code", true, {
								["main.mxl"] = {
									kind = "file",
									content = ExamplePrograms.buildCodeLibraryImage(),
								},
								["source.msh"] = {
									kind = "file",
									content = MTSharpPrograms.CodeEditorApp,
								},
							}),
							notepad = makeAppNode(ExamplePrograms.buildNotepadImage(), "Notepad", true),
							settings = makeAppNode(ExamplePrograms.buildSettingsLauncherImage(), "Settings", true, {
								["main.mxl"] = {
									kind = "file",
									content = ExamplePrograms.buildSettingsLibraryImage(),
								},
								["source.msh"] = {
									kind = "file",
									content = MTSharpPrograms.SettingsApp,
								},
							}),
						},
					},
				},
			},
			www = {
				kind = "dir",
				children = {
					["website.tux"] = {
						kind = "dir",
						children = {
							["site.mxl"] = {
								kind = "file",
								content = ExamplePrograms.buildMtxDTExampleSiteImage(),
							},
							["site.msh"] = {
								kind = "file",
								content = MTSharpPrograms.MtxDTExampleSite,
							},
							["site.json"] = {
								kind = "file",
								content = '{"host":"website.tux","ip":"10.0.0.5","port":80,"entry":"site.mxl"}',
							},
						},
					},
				},
			},
			lib = {
				kind = "dir",
				children = {
					ui = {
						kind = "dir",
						children = {
							["gui.mxl"] = {
								kind = "file",
								content = GUILibrary,
							},
							["motion.mxl"] = {
								kind = "file",
								content = UIMotionLibrary,
							},
						},
					},
					core = {
						kind = "dir",
						children = {
							["json.mxl"] = {
								kind = "file",
								content = JSONLibrary,
							},
							["string.mxl"] = {
								kind = "file",
								content = StringLibrary,
							},
						},
					},
					web = {
						kind = "dir",
						children = {
							["mtxdt.mxl"] = {
								kind = "file",
								content = MtxDTLibrary,
							},
						},
					},
					sharp = {
						kind = "dir",
						children = {
							Mentux = {
								kind = "dir",
								children = {
									Web = {
										kind = "dir",
										children = {
											["MtxDT.mxl"] = {
												kind = "file",
												content = MtxDTLibrary,
											},
										},
									},
								},
							},
							Libraries = {
								kind = "dir",
								children = {
									["Json.mxl"] = {
										kind = "file",
										content = SharpJSONLibrary,
									},
								},
							},
							System = {
								kind = "dir",
								children = {
									["Gui.mxl"] = {
										kind = "file",
										content = SharpSystemGuiLibrary,
									},
									["IO.mxl"] = {
										kind = "file",
										content = SharpSystemIOLibrary,
									},
									["String.mxl"] = {
										kind = "file",
										content = SharpSystemStringLibrary,
									},
								},
							},
						},
					},
				},
			},
			etc = {
				kind = "dir",
				children = {
					["motd.txt"] = {
						kind = "file",
						content = "Welcome to Mentux OS. This guest kernel is running on a custom VM, not Luau bytecode.\nTry the Browser app with mtx://website.tux/.",
					},
				},
			},
			var = {
				kind = "dir",
				children = {
					log = {
						kind = "dir",
						children = {},
					},
				},
			},
		},
	}
end

return ExamplePrograms
