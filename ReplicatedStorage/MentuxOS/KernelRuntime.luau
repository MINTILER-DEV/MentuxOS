local CPU = require(script.Parent:WaitForChild("CPU"))
local ExecutableFormat = require(script.Parent:WaitForChild("ExecutableFormat"))
local LibraryFormat = require(script.Parent:WaitForChild("LibraryFormat"))
local Loader = require(script.Parent:WaitForChild("Loader"))
local Memory = require(script.Parent:WaitForChild("Memory"))
local Syscalls = require(script.Parent:WaitForChild("Syscalls"))
local Util = require(script.Parent:WaitForChild("Util"))
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KernelRuntime = {}
KernelRuntime.__index = KernelRuntime

function KernelRuntime.new(options)
	assert(options and options.vfs, "KernelRuntime requires a virtual filesystem")

	local self = setmetatable({}, KernelRuntime)
	self.vfs = options.vfs
	self.logger = options.logger or function(message)
		print(message)
	end
	self.guiController = options.guiController
	self.trace = options.trace == true
	self.memorySize = options.memorySize or 8192
	self.defaultMaxCycles = options.defaultMaxCycles or 10000000
	self.nextPid = 1
	self.processes = {}
	self.syscalls = Syscalls.new()
	self:_registerCoreSyscalls()
	return self
end

function KernelRuntime:_log(message)
	self.logger("[MentuxOS] " .. message)
end

function KernelRuntime:_requireGUI()
	assert(self.guiController, "This Mentux runtime was started without a GUI controller")
	return self.guiController
end

function KernelRuntime:_requireHTTPBridge()
	local mentuxRoot = ReplicatedStorage:WaitForChild("MentuxOS")
	local runtimeFolder = mentuxRoot:WaitForChild("Runtime", 5)
	assert(runtimeFolder, "Mentux HTTP bridge runtime folder is unavailable")
	local bridge = runtimeFolder:WaitForChild("HttpBridge", 5)
	assert(bridge, "Mentux HTTP bridge remote is unavailable")
	return bridge
end

function KernelRuntime:_normalizeArgv(argv, preserveRefs)
	if argv == nil then
		return {}
	end

	if type(argv) == "table" then
		if preserveRefs then
			local cloned = {}
			for index, value in ipairs(argv) do
				cloned[index] = value
			end
			return cloned
		end
		return Util.deepCopy(argv)
	end

	return { argv }
end

function KernelRuntime:_normalizeCallArgs(args)
	if args == nil then
		return {}
	end

	if type(args) == "table" then
		return Util.deepCopy(args)
	end

	return { Util.deepCopy(args) }
end

function KernelRuntime:_normalizeEnv(env)
	local normalized = {
		PATH = "/bin:/boot",
	}

	for key, value in pairs(env or {}) do
		normalized[key] = Util.deepCopy(value)
	end

	return normalized
end

function KernelRuntime:_sliceList(values, startIndex)
	local list = {}
	if type(values) ~= "table" then
		return list
	end

	for index = math.max(1, startIndex or 1), #values do
		table.insert(list, Util.deepCopy(values[index]))
	end

	return list
end

function KernelRuntime:_listProcesses()
	local entries = {}
	for pid, process in pairs(self.processes) do
		table.insert(entries, {
			pid = pid,
			parentPid = process.parentPid or 0,
			path = tostring(process.path or "?"),
		})
	end

	table.sort(entries, function(left, right)
		return left.pid < right.pid
	end)

	local lines = {}
	for _, entry in ipairs(entries) do
		table.insert(lines, string.format("%d %d %s", entry.pid, entry.parentPid, entry.path))
	end
	return lines
end

function KernelRuntime:_currentModulePath(process)
	local path = tostring(process.path or "")
	local splitIndex = string.find(path, "::", 1, true)
	if splitIndex then
		return string.sub(path, 1, splitIndex - 1)
	end
	return path
end

function KernelRuntime:_guiScopePrefix(process)
	return string.format("p%d", tonumber(process and process.pid) or 0)
end

function KernelRuntime:_guiScopeId(process, id)
	local value = tostring(id or "")
	if value == "" or value == "root" or value == "__root" then
		return value
	end
	return string.format("%s::%s", self:_guiScopePrefix(process), value)
end

function KernelRuntime:_stripGuiScope(process, id)
	local value = tostring(id or "")
	local prefix = self:_guiScopePrefix(process) .. "::"
	if value:sub(1, #prefix) == prefix then
		return value:sub(#prefix + 1)
	end
	return value
end

function KernelRuntime:_normalizePath(path)
	local raw = tostring(path or "")
	local parts = {}

	for segment in string.gmatch(raw, "[^/]+") do
		if segment == "." or segment == "" then
			-- ignore
		elseif segment == ".." then
			if #parts > 0 then
				table.remove(parts)
			end
		else
			table.insert(parts, segment)
		end
	end

	return "/" .. table.concat(parts, "/")
end

function KernelRuntime:_buildSharpLibraryCandidates(namespaceName)
	local parts = {}
	for segment in string.gmatch(tostring(namespaceName or ""), "[^%.]+") do
		table.insert(parts, segment)
	end

	local candidates = {}
	for endIndex = #parts, 1, -1 do
		table.insert(candidates, "/lib/sharp/" .. table.concat(parts, "/", 1, endIndex) .. ".mxl")
	end
	return candidates
end

function KernelRuntime:_resolveSharpLibraryExport(process, spec, exportName)
	local tried = {}
	local descriptor = tostring(spec or "")
	local namespaceList = descriptor:match("^sharp:(.+)$") or ""

	for namespaceName in string.gmatch(namespaceList, "[^;]+") do
		for _, candidatePath in ipairs(self:_buildSharpLibraryCandidates(namespaceName)) do
			table.insert(tried, candidatePath)
			if self.vfs:exists(candidatePath) then
				local library = self.vfs:readFile(candidatePath)
				if type(library) == "table" and library.magic == LibraryFormat.MAGIC then
					LibraryFormat.validate(library)
					local exportValue = library.exports[exportName]
					if exportValue ~= nil then
						return candidatePath, library, exportValue, tried
					end
				end
			end
		end
	end

	return nil, nil, nil, tried
end

function KernelRuntime:_resolvePath(process, target)
	local path = tostring(target or "")
	if path == "" then
		return self:_normalizePath(process.env.PWD or "/")
	end

	if path:sub(1, 1) == "/" then
		return self:_normalizePath(path)
	end

	local cwd = tostring(process.env.PWD or "/")
	if cwd:sub(-1) ~= "/" then
		cwd ..= "/"
	end
	return self:_normalizePath(cwd .. path)
end

function KernelRuntime:_resolveProgramPath(process, command)
	if type(command) ~= "string" or command == "" then
		return false
	end

	local candidates = {}

	local function pushCandidate(path)
		if path == nil or path == "" then
			return
		end

		table.insert(candidates, path)
		if not path:match("%.mtx$") then
			table.insert(candidates, path .. ".mtx")
			table.insert(candidates, path .. "/main.mtx")
		end
	end

	if command:sub(1, 1) == "/" or command:find("/") then
		pushCandidate(self:_resolvePath(process, command))
	else
		for segment in string.gmatch(tostring(process.env.PATH or ""), "[^:]+") do
			local base = segment
			if base:sub(-1) == "/" then
				base = base:sub(1, -2)
			end
			pushCandidate(base .. "/" .. command)
		end
	end

	for _, candidate in ipairs(candidates) do
		if self.vfs:exists(candidate) then
			local stat = self.vfs:stat(candidate)
			if stat and stat.kind == "file" then
				return candidate
			end
		end
	end

	return false
end

function KernelRuntime:_renderMetadata(metadata)
	local lines = {}
	local keys = {}

	for key in pairs(metadata or {}) do
		table.insert(keys, tostring(key))
	end

	table.sort(keys)
	for _, key in ipairs(keys) do
		table.insert(lines, string.format("%s: %s", key, Util.stringify(metadata[key])))
	end

	return lines
end

function KernelRuntime:_formatInstructionValue(value)
	if type(value) ~= "table" then
		if type(value) == "string" then
			return string.format("%q", value)
		end
		return tostring(value)
	end

	if value.section ~= nil then
		return string.format("%s:%s", tostring(value.section), tostring(value.offset))
	end

	return Util.stringify(value)
end

function KernelRuntime:_renderInstructionPreview(code, limit)
	local lines = {}
	local available = #(code or {})
	local count = available
	if limit ~= nil then
		count = math.min(available, limit)
	end

	for index = 1, count do
		local instruction = code[index]
		if type(instruction) == "table" then
			local parts = {}
			for key, value in pairs(instruction) do
				if key ~= "op" then
					table.insert(parts, string.format("%s=%s", tostring(key), self:_formatInstructionValue(value)))
				end
			end
			table.sort(parts)
			table.insert(
				lines,
				string.format("[%03d] %s%s", index - 1, tostring(instruction.op), #parts > 0 and (" " .. table.concat(parts, " ")) or "")
			)
		else
			table.insert(lines, string.format("[%03d] <invalid>", index - 1))
		end
	end

	if limit ~= nil and #(code or {}) > count then
		table.insert(lines, string.format("... +%d more instruction(s)", #(code or {}) - count))
	end

	return lines
end

function KernelRuntime:_appendInstructionSection(lines, title, code, limit)
	local previewLines = self:_renderInstructionPreview(code or {}, limit)
	if #previewLines == 0 then
		return
	end

	table.insert(lines, title)
	for _, line in ipairs(previewLines) do
		table.insert(lines, "  " .. line)
	end
end

function KernelRuntime:_describeExecutable(path, executable, previewLimit)
	local lines = {
		"Mentux Executable",
		string.format("Path: %s", path),
		string.format("Name: %s", executable.name),
		string.format("Kind: %s", tostring(executable.kind or "program")),
		string.format("Version: %s", tostring(executable.version)),
		string.format("Entry Point: %s", tostring(executable.entryPoint)),
		string.format("Stack Size: %s", tostring(executable.stackSize)),
		string.format("Instructions: %s", tostring(#(executable.code or {}))),
		string.format("Data Cells: %s", tostring(#(executable.data or {}))),
	}

	local metadataLines = self:_renderMetadata(executable.metadata or {})
	if #metadataLines > 0 then
		table.insert(lines, "Metadata:")
		for _, line in ipairs(metadataLines) do
			table.insert(lines, "  " .. line)
		end
	end

	self:_appendInstructionSection(lines, "Instructions:", executable.code or {}, previewLimit == nil and 14 or previewLimit)

	return table.concat(lines, "\n")
end

function KernelRuntime:_describeLibrary(path, library, previewLimit)
	local lines = {
		"Mentux Library",
		string.format("Path: %s", path),
		string.format("Name: %s", library.name),
		string.format("Kind: %s", tostring(library.kind or "library")),
		string.format("Version: %s", tostring(library.version)),
	}

	local exportNames = {}
	for exportName, exportValue in pairs(library.exports or {}) do
		local suffix = ""
		if type(exportValue) == "table" and exportValue.magic == ExecutableFormat.MAGIC then
			suffix = " [code]"
		elseif type(exportValue) == "table" and exportValue.kind == "native" then
			suffix = " [native]"
		elseif type(exportValue) == "table" then
			suffix = " [data]"
		end
		table.insert(exportNames, tostring(exportName) .. suffix)
	end
	table.sort(exportNames)
	table.insert(lines, string.format("Exports: %s", #exportNames > 0 and table.concat(exportNames, ", ") or "<none>"))

	local metadataLines = self:_renderMetadata(library.metadata or {})
	if #metadataLines > 0 then
		table.insert(lines, "Metadata:")
		for _, line in ipairs(metadataLines) do
			table.insert(lines, "  " .. line)
		end
	end

	local executableExportNames = {}
	for exportName, exportValue in pairs(library.exports or {}) do
		if type(exportValue) == "table" and exportValue.magic == ExecutableFormat.MAGIC then
			table.insert(executableExportNames, exportName)
		end
	end
	table.sort(executableExportNames)

	local exportLimit = previewLimit == nil and math.min(#executableExportNames, 2) or #executableExportNames
	if exportLimit > 0 then
		table.insert(lines, "Export Instructions:")
		for index = 1, exportLimit do
			local exportName = executableExportNames[index]
			local exportValue = library.exports[exportName]
			table.insert(lines, "  " .. tostring(exportName) .. ":")
			local exportPreviewLines = self:_renderInstructionPreview(exportValue.code or {}, previewLimit == nil and 8 or previewLimit)
			for _, line in ipairs(exportPreviewLines) do
				table.insert(lines, "    " .. line)
			end
		end

		if previewLimit == nil and #executableExportNames > exportLimit then
			table.insert(lines, string.format("  ... +%d more executable export(s)", #executableExportNames - exportLimit))
		end
	end

	return table.concat(lines, "\n")
end

function KernelRuntime:_describeFile(path, previewLimit)
	local content = self.vfs:readFile(path)
	local effectivePreviewLimit = previewLimit
	if effectivePreviewLimit == false then
		effectivePreviewLimit = 14
	end

	if type(content) == "table" then
		if content.magic == ExecutableFormat.MAGIC then
			ExecutableFormat.validate(content)
			return self:_describeExecutable(path, content, effectivePreviewLimit)
		end

		if content.magic == LibraryFormat.MAGIC then
			LibraryFormat.validate(content)
			return self:_describeLibrary(path, content, effectivePreviewLimit == 14 and 8 or effectivePreviewLimit)
		end
	end

	if type(content) == "string" then
		return content
	end

	return Util.stringify(content)
end

function KernelRuntime:_normalizeHeaderTokens(value)
	if type(value) ~= "table" then
		return {}
	end

	local headers = {}
	for _, entry in ipairs(value) do
		table.insert(headers, tostring(entry))
	end
	return headers
end

function KernelRuntime:_tryParseJSON(source)
	local ok, result = pcall(function()
		return HttpService:JSONDecode(tostring(source or ""))
	end)
	if ok then
		return result
	end
	return false
end

function KernelRuntime:_makeException(kind, message, data)
	local exception = {
		__type = tostring(kind or "Exception"),
		message = tostring(message or ""),
	}

	if type(data) == "table" then
		for key, value in pairs(data) do
			exception[key] = value
		end
	end

	return exception
end

function KernelRuntime:_normalizeExceptionValue(value)
	if type(value) == "table" then
		local exception = value
		exception.__type = tostring(exception.__type or "Exception")
		if exception.message == nil then
			exception.message = tostring(exception.value or exception.reason or exception.__type)
		end
		return exception
	end

	return self:_makeException("Exception", tostring(value), {
		value = value,
	})
end

function KernelRuntime:_captureException(process, kind, message, data)
	process.pendingException = self:_makeException(kind, message, data)
	return process.pendingException
end

function KernelRuntime:_matchExceptionType(exceptionValue, typeName)
	local target = tostring(typeName or "Exception")
	if target == "" or target == "Exception" or target == "System.Exception" then
		return exceptionValue ~= nil
	end

	if type(exceptionValue) ~= "table" then
		return false
	end

	local actualType = tostring(exceptionValue.__type or "")
	if actualType == target then
		return true
	end

	local shortActual = actualType:match("([^.]+)$") or actualType
	local shortTarget = target:match("([^.]+)$") or target
	return shortActual == shortTarget
end

function KernelRuntime:_registerCoreSyscalls()
	self.syscalls:register("write", function(runtime, process, args)
		local rendered = Util.stringify(args[1])
		runtime:_log(string.format("[%s#%d] %s", process.path, process.pid, rendered))
		return #rendered
	end)

	self.syscalls:register("gui.reset", function(runtime, process)
		return runtime:_requireGUI():resetScope(runtime:_guiScopePrefix(process))
	end)

	self.syscalls:register("gui.panel", function(runtime, process, args)
		return runtime:_requireGUI():createPanel(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), tonumber(args[3]) or 0, tonumber(args[4]) or 0, tonumber(args[5]) or 0.4, tonumber(args[6]) or 0.2, tostring(args[7] or "panel"))
	end)

	self.syscalls:register("gui.label", function(runtime, process, args)
		return runtime:_requireGUI():createLabel(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), Util.stringify(args[3]), tonumber(args[4]) or 0, tonumber(args[5]) or 0, tonumber(args[6]) or 0.4, tonumber(args[7]) or 0.08)
	end)

	self.syscalls:register("gui.button", function(runtime, process, args)
		return runtime:_requireGUI():createButton(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), tostring(args[3] or ""), tonumber(args[4]) or 0, tonumber(args[5]) or 0, tonumber(args[6]) or 0.2, tonumber(args[7]) or 0.08)
	end)

	self.syscalls:register("gui.enableDrag", function(runtime, process, args)
		return runtime:_requireGUI():enableDrag(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2] or args[1]))
	end)

	self.syscalls:register("gui.setDraggable", function(runtime, process, args)
		return runtime:_requireGUI():setDraggable(runtime:_guiScopeId(process, args[1]), args[2] ~= false, runtime:_guiScopeId(process, args[3] or args[1]))
	end)

	self.syscalls:register("gui.textbox", function(runtime, process, args)
		return runtime:_requireGUI():createTextBox(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), tostring(args[3] or ""), tostring(args[4] or ""), tonumber(args[5]) or 0, tonumber(args[6]) or 0, tonumber(args[7]) or 0.4, tonumber(args[8]) or 0.08, args[9] == true, args[10] == true)
	end)

	self.syscalls:register("gui.scrollFrame", function(runtime, process, args)
		return runtime:_requireGUI():createScrollFrame(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), tonumber(args[3]) or 0, tonumber(args[4]) or 0, tonumber(args[5]) or 0.4, tonumber(args[6]) or 0.2, tonumber(args[7]))
	end)

	self.syscalls:register("gui.textarea", function(runtime, process, args)
		return runtime:_requireGUI():createTextArea(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), tostring(args[3] or ""), tonumber(args[4]) or 0, tonumber(args[5]) or 0, tonumber(args[6]) or 0.4, tonumber(args[7]) or 0.2)
	end)

	self.syscalls:register("gui.richText", function(runtime, process, args)
		return runtime:_requireGUI():createRichTextArea(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]), tostring(args[3] or ""), tonumber(args[4]) or 0, tonumber(args[5]) or 0, tonumber(args[6]) or 0.4, tonumber(args[7]) or 0.2)
	end)

	self.syscalls:register("gui.setText", function(runtime, process, args)
		return runtime:_requireGUI():setText(runtime:_guiScopeId(process, args[1]), Util.stringify(args[2]))
	end)

	self.syscalls:register("gui.getText", function(runtime, process, args)
		return runtime:_requireGUI():getText(runtime:_guiScopeId(process, args[1]))
	end)

	self.syscalls:register("gui.appendText", function(runtime, process, args)
		return runtime:_requireGUI():appendText(runtime:_guiScopeId(process, args[1]), Util.stringify(args[2]))
	end)

	self.syscalls:register("gui.anchor", function(runtime, process, args)
		return runtime:_requireGUI():setAnchorPoint(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 0, tonumber(args[3]) or 0)
	end)

	self.syscalls:register("gui.setBackgroundColor", function(runtime, process, args)
		return runtime:_requireGUI():setBackgroundColor(runtime:_guiScopeId(process, args[1]), tostring(args[2] or "panel"))
	end)

	self.syscalls:register("gui.setTextColor", function(runtime, process, args)
		return runtime:_requireGUI():setTextColor(runtime:_guiScopeId(process, args[1]), tostring(args[2] or "text"))
	end)

	self.syscalls:register("gui.setStrokeColor", function(runtime, process, args)
		return runtime:_requireGUI():setStrokeColor(runtime:_guiScopeId(process, args[1]), tostring(args[2] or "stroke"))
	end)

	self.syscalls:register("gui.setSize", function(runtime, process, args)
		return runtime:_requireGUI():setSize(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 0, tonumber(args[3]) or 0)
	end)

	self.syscalls:register("gui.setPosition", function(runtime, process, args)
		return runtime:_requireGUI():setPosition(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 0, tonumber(args[3]) or 0)
	end)

	self.syscalls:register("gui.setVisible", function(runtime, process, args)
		return runtime:_requireGUI():setVisible(runtime:_guiScopeId(process, args[1]), args[2] == true)
	end)

	self.syscalls:register("gui.setParent", function(runtime, process, args)
		return runtime:_requireGUI():setParent(runtime:_guiScopeId(process, args[1]), runtime:_guiScopeId(process, args[2]))
	end)

	self.syscalls:register("gui.setZIndex", function(runtime, process, args)
		return runtime:_requireGUI():setZIndex(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 1)
	end)

	self.syscalls:register("gui.setFont", function(runtime, process, args)
		return runtime:_requireGUI():setFont(runtime:_guiScopeId(process, args[1]), tostring(args[2] or "Code"))
	end)

	self.syscalls:register("gui.setTextSize", function(runtime, process, args)
		return runtime:_requireGUI():setTextSize(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 16)
	end)

	self.syscalls:register("gui.setImage", function(runtime, process, args)
		return runtime:_requireGUI():setImage(runtime:_guiScopeId(process, args[1]), tostring(args[2] or ""))
	end)

	self.syscalls:register("gui.tween", function(runtime, process, args)
		return runtime:_requireGUI():tween(
			runtime:_guiScopeId(process, args[1]),
			tostring(args[2] or "position"),
			args[3],
			args[4],
			tonumber(args[5]) or 0.18,
			tostring(args[6] or "linear"),
			tonumber(args[7]) or 10
		)
	end)

	self.syscalls:register("gui.corner", function(runtime, process, args)
		return runtime:_requireGUI():setCornerRadius(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 14)
	end)

	self.syscalls:register("gui.padding", function(runtime, process, args)
		return runtime:_requireGUI():addPadding(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 0, tonumber(args[3]) or 0, tonumber(args[4]) or 0, tonumber(args[5]) or 0)
	end)

	self.syscalls:register("gui.listLayout", function(runtime, process, args)
		return runtime:_requireGUI():addListLayout(runtime:_guiScopeId(process, args[1]), tostring(args[2] or "vertical"), tonumber(args[3]) or 0.01, tostring(args[4] or "left"), tostring(args[5] or "top"))
	end)

	self.syscalls:register("gui.backgroundTransparency", function(runtime, process, args)
		return runtime:_requireGUI():setBackgroundTransparency(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 0)
	end)

	self.syscalls:register("gui.textTransparency", function(runtime, process, args)
		return runtime:_requireGUI():setTextTransparency(runtime:_guiScopeId(process, args[1]), tonumber(args[2]) or 0)
	end)

	self.syscalls:register("gui.destroy", function(runtime, process, args)
		return runtime:_requireGUI():destroy(runtime:_guiScopeId(process, args[1]))
	end)

	self.syscalls:register("gui.waitEvent", function(runtime, process)
		local event = runtime:_requireGUI():waitEventForPrefix(runtime:_guiScopePrefix(process))
		if type(event) ~= "table" then
			return event
		end
		return {
			event[1],
			runtime:_stripGuiScope(process, event[2]),
			Util.deepCopy(event[3]),
		}
	end)

	self.syscalls:register("input.capture", function(runtime)
		return runtime:_requireGUI():startInputCapture()
	end)

	self.syscalls:register("input.release", function(runtime)
		return runtime:_requireGUI():stopInputCapture()
	end)

	self.syscalls:register("input.clear", function(runtime)
		return runtime:_requireGUI():clearInputEvents()
	end)

	self.syscalls:register("input.wait", function(runtime)
		return runtime:_requireGUI():waitInputEvent()
	end)

	self.syscalls:register("value.len", function(_, _, args)
		local value = args[1]
		if type(value) == "string" or type(value) == "table" then
			return #value
		end
		return 0
	end)

	self.syscalls:register("value.toNumber", function(_, _, args)
		return tonumber(args[1]) or 0
	end)

	self.syscalls:register("str.charAt", function(_, _, args)
		local value = tostring(args[1] or "")
		local index = math.max(1, tonumber(args[2]) or 1)
		return value:sub(index, index)
	end)

	self.syscalls:register("list.new", function()
		return {}
	end)

	self.syscalls:register("list.push", function(_, _, args)
		local list = args[1]
		if type(list) ~= "table" then
			list = {}
		end
		table.insert(list, Util.deepCopy(args[2]))
		return list
	end)

	self.syscalls:register("list.get", function(_, _, args)
		local list = args[1]
		local index = tonumber(args[2]) or 1
		if type(list) ~= "table" then
			return nil
		end
		return Util.deepCopy(list[index])
	end)

	self.syscalls:register("list.slice", function(runtime, _, args)
		return runtime:_sliceList(args[1], tonumber(args[2]) or 1)
	end)

	self.syscalls:register("map.get", function(_, _, args)
		local map = args[1]
		local key = args[2]
		if type(map) ~= "table" then
			return nil
		end
		return Util.deepCopy(map[key])
	end)

	self.syscalls:register("obj.new", function(_, _, args)
		return {
			__type = tostring(args[1] or "Object"),
			__modulePath = tostring(args[2] or ""),
		}
	end)

	self.syscalls:register("obj.get", function(_, _, args)
		local object = args[1]
		local key = tostring(args[2] or "")
		if type(object) ~= "table" then
			return nil
		end
		return object[key]
	end)

	self.syscalls:register("obj.set", function(_, _, args)
		local object = args[1]
		local key = tostring(args[2] or "")
		if type(object) ~= "table" then
			return false
		end
		object[key] = args[3]
		return object
	end)

	self.syscalls:register("proc.argc", function(_, process)
		return #process.argv
	end)

	self.syscalls:register("proc.pid", function(_, process)
		return process.pid
	end)

	self.syscalls:register("proc.argv", function(_, process, args)
		local index = tonumber(args[1]) or 1
		local value = process.argv[index]
		if process.preserveArgvRefs then
			return value
		end
		return Util.deepCopy(value)
	end)

	self.syscalls:register("proc.modulePath", function(runtime, process)
		return runtime:_currentModulePath(process)
	end)

	self.syscalls:register("proc.list", function(runtime)
		return runtime:_listProcesses()
	end)

	self.syscalls:register("proc.kill", function(runtime, _, args)
		local pid = tonumber(args[1]) or -1
		local exitCode = tonumber(args[2]) or 143
		local target = runtime.processes[pid]
		if not target then
			return false
		end

		target.exitCode = target.exitCode or exitCode
		if target.cpu then
			target.cpu:halt()
		end
		return true
	end)

	self.syscalls:register("env.get", function(_, process, args)
		local key = tostring(args[1] or "")
		return Util.deepCopy(process.env[key])
	end)

	self.syscalls:register("env.set", function(_, process, args)
		local key = tostring(args[1] or "")
		process.env[key] = Util.deepCopy(args[2])
		return Util.deepCopy(process.env[key])
	end)

	self.syscalls:register("resolveExec", function(runtime, process, args)
		return runtime:_resolveProgramPath(process, args[1])
	end)

	self.syscalls:register("resolvePath", function(runtime, process, args)
		return runtime:_resolvePath(process, args[1])
	end)

	self.syscalls:register("statKind", function(runtime, process, args)
		local path = runtime:_resolvePath(process, args[1])
		local stat = runtime.vfs:stat(path)
		if not stat then
			return false
		end
		return stat.kind
	end)

	self.syscalls:register("readFile", function(runtime, process, args)
		return runtime.vfs:readFile(runtime:_resolvePath(process, args[1]))
	end)

	self.syscalls:register("fileInfo", function(runtime, process, args)
		return runtime:_describeFile(runtime:_resolvePath(process, args[1]), false)
	end)

	self.syscalls:register("fileSummary", function(runtime, process, args)
		local limit = tonumber(args[2])
		if limit ~= nil then
			limit = math.max(0, math.floor(limit))
		end
		return runtime:_describeFile(runtime:_resolvePath(process, args[1]), limit)
	end)

	self.syscalls:register("json.parse", function(runtime, _, args)
		return runtime:_tryParseJSON(args[1])
	end)

	self.syscalls:register("json.encode", function(_, _, args)
		local ok, result = pcall(function()
			return HttpService:JSONEncode(args[1])
		end)
		if ok then
			return result
		end
		return false
	end)

	self.syscalls:register("safe.invoke", function(runtime, process, args)
		local syscallName = tostring(args[1] or "")
		local callArgs = args[2]
		if type(callArgs) ~= "table" then
			callArgs = if callArgs == nil then {} else { callArgs }
		end

		local ok, result = pcall(function()
			return runtime.syscalls:invoke(syscallName, runtime, process, callArgs)
		end)

		if ok then
			return result
		end

		local errorText = tostring(result)
		local exceptionKind = "RuntimeException"
		if string.find(errorText, "No file at ", 1, true) then
			exceptionKind = "FileNotFoundException"
		elseif string.find(errorText, "No directory at ", 1, true) then
			exceptionKind = "DirectoryNotFoundException"
		elseif string.find(errorText, "Division by zero", 1, true) then
			exceptionKind = "DivideByZeroException"
		elseif string.find(errorText, "command not found", 1, true) then
			exceptionKind = "CommandNotFoundException"
		end

		runtime:_captureException(process, exceptionKind, errorText, {
			syscall = syscallName,
		})
		return nil
	end)

	self.syscalls:register("invoke", function(runtime, process, args)
		local syscallName = tostring(args[1] or "")
		local callArgs = args[2]
		if type(callArgs) ~= "table" then
			callArgs = if callArgs == nil then {} else { callArgs }
		end
		return runtime.syscalls:invoke(syscallName, runtime, process, callArgs)
	end)

	self.syscalls:register("exc.throw", function(runtime, process, args)
		process.pendingException = runtime:_normalizeExceptionValue(args[1])
		return process.pendingException
	end)

	self.syscalls:register("exc.has", function(_, process)
		return process.pendingException ~= nil
	end)

	self.syscalls:register("exc.peek", function(_, process)
		return process.pendingException
	end)

	self.syscalls:register("exc.take", function(_, process)
		local value = process.pendingException
		process.pendingException = nil
		return value
	end)

	self.syscalls:register("exc.clear", function(_, process)
		process.pendingException = nil
		return true
	end)

	self.syscalls:register("exc.match", function(runtime, _, args)
		return runtime:_matchExceptionType(args[1], args[2])
	end)

	self.syscalls:register("exc.raisePending", function(_, process)
		if process.pendingException ~= nil then
			error(tostring(process.pendingException.message or process.pendingException.__type or "Unhandled exception"))
		end
		return false
	end)

	self.syscalls:register("lib.call", function(runtime, process, args)
		local rawLibraryPath = tostring(args[1] or "")
		local exportName = tostring(args[2] or "")
		local libraryPath = nil
		local library = nil
		local exportValue = nil

		if rawLibraryPath:sub(1, 6) == "sharp:" then
			libraryPath, library, exportValue = runtime:_resolveSharpLibraryExport(process, rawLibraryPath, exportName)
			assert(
				libraryPath ~= nil,
				string.format("Unable to resolve sharp library export %s from %s", exportName, rawLibraryPath)
			)
		else
			libraryPath = runtime:_resolvePath(process, rawLibraryPath)
			library = runtime.vfs:readFile(libraryPath)
			LibraryFormat.validate(library)
			exportValue = library.exports[exportName]
			assert(exportValue ~= nil, "Unknown library export " .. exportName)
		end

		if type(exportValue) == "table" and exportValue.kind == "native" then
			assert(type(exportValue.syscall) == "string" and exportValue.syscall ~= "", "Native library export is missing a syscall name")
			return runtime.syscalls:invoke(exportValue.syscall, runtime, process, runtime:_normalizeCallArgs(args[3]))
		end

		if type(exportValue) == "table" and exportValue.magic == ExecutableFormat.MAGIC then
			local callArgs = runtime:_normalizeCallArgs(args[3])
			local result = runtime:runImage(exportValue, {
				path = string.format("%s::%s", libraryPath, exportName),
				argv = callArgs,
				parentPid = process.pid,
				env = runtime:_normalizeEnv(process.env),
				maxCycles = process.maxCycles,
				preserveArgvRefs = true,
			})
			if result.ok == false then
				error(string.format("Library export %s failed: %s", exportName, tostring(result.error)))
			end

			if result.returnValue ~= nil then
				return result.returnValue
			end

			return result.exitCode
		end

		return Util.deepCopy(exportValue)
	end)

	self.syscalls:register("obj.callMethod", function(runtime, process, args)
		local object = args[1]
		local memberName = tostring(args[2] or "")
		local extraArgs = runtime:_normalizeCallArgs(args[3])
		assert(type(object) == "table", "obj.callMethod requires an object table")

		local modulePath = tostring(object.__modulePath or "")
		local objectType = tostring(object.__type or "")
		assert(modulePath ~= "", "Object is missing __modulePath")
		assert(objectType ~= "", "Object is missing __type")

		local exportName = string.format("%s.%s", objectType, memberName)
		local libraryPath = runtime:_resolvePath(process, modulePath)
		local library = runtime.vfs:readFile(libraryPath)
		LibraryFormat.validate(library)

		local exportValue = library.exports[exportName]
		assert(exportValue ~= nil, "Unknown object method export " .. exportName)
		assert(type(exportValue) == "table" and exportValue.magic == ExecutableFormat.MAGIC, "Object method export is not executable")

		local argv = { object }
		for _, value in ipairs(extraArgs) do
			table.insert(argv, value)
		end

		local result = runtime:runImage(exportValue, {
			path = string.format("%s::%s", libraryPath, exportName),
			argv = argv,
			parentPid = process.pid,
			env = runtime:_normalizeEnv(process.env),
			maxCycles = process.maxCycles,
			preserveArgvRefs = true,
		})

		if result.ok == false then
			error(string.format("Object method %s failed: %s", exportName, tostring(result.error)))
		end

		if result.returnValue ~= nil then
			return result.returnValue
		end

		return result.exitCode
	end)

	self.syscalls:register("http.request", function(runtime, process, args)
		local bridge = runtime:_requireHTTPBridge()
		local request = {
			url = tostring(args[1] or ""),
			method = tostring(args[2] or "GET"),
			headers = runtime:_normalizeHeaderTokens(args[3]),
			body = args[4],
		}

		local response = bridge:InvokeServer(request)
		return {
			response.ok == true,
			tonumber(response.statusCode) or 0,
			tostring(response.statusMessage or ""),
			tostring(response.body or ""),
			tonumber(response.elapsedMs) or 0,
			tostring(response.url or request.url),
			tostring(response.headers or ""),
		}
	end)

	self.syscalls:register("writeFile", function(runtime, process, args)
		runtime.vfs:writeFile(runtime:_resolvePath(process, args[1]), args[2])
		return true
	end)

	self.syscalls:register("appendFile", function(runtime, process, args)
		runtime.vfs:appendFile(runtime:_resolvePath(process, args[1]), args[2])
		return true
	end)

	self.syscalls:register("mkdir", function(runtime, process, args)
		runtime.vfs:ensureDirectory(runtime:_resolvePath(process, args[1]))
		return true
	end)

	self.syscalls:register("deletePath", function(runtime, process, args)
		return runtime.vfs:deletePath(runtime:_resolvePath(process, args[1]))
	end)

	self.syscalls:register("movePath", function(runtime, process, args)
		return runtime.vfs:movePath(
			runtime:_resolvePath(process, args[1]),
			runtime:_resolvePath(process, args[2])
		)
	end)

	self.syscalls:register("exists", function(runtime, process, args)
		return runtime.vfs:exists(runtime:_resolvePath(process, args[1]))
	end)

	self.syscalls:register("stat", function(runtime, process, args)
		return runtime.vfs:stat(runtime:_resolvePath(process, args[1]))
	end)

	self.syscalls:register("listDir", function(runtime, process, args)
		return runtime.vfs:listDir(runtime:_resolvePath(process, args[1]))
	end)

	self.syscalls:register("exec", function(runtime, process, args)
		local path = runtime:_resolveProgramPath(process, args[1])
		if not path then
			runtime:_log(string.format("[%s#%d] command not found: %s", process.path, process.pid, tostring(args[1])))
			return 127
		end

		local argv = runtime:_normalizeArgv(args[2])
		local image = runtime.vfs:readFile(path)
		local result = runtime:runImage(image, {
			path = path,
			argv = argv,
			parentPid = process.pid,
			env = runtime:_normalizeEnv(process.env),
			maxCycles = process.maxCycles,
		})
		return result.exitCode
	end)

	self.syscalls:register("exec.async", function(runtime, process, args)
		local path = runtime:_resolveProgramPath(process, args[1])
		if not path then
			runtime:_log(string.format("[%s#%d] command not found: %s", process.path, process.pid, tostring(args[1])))
			return 0
		end

		local argv = runtime:_normalizeArgv(args[2])
		local image = runtime.vfs:readFile(path)
		return runtime:spawnImage(image, {
			path = path,
			argv = argv,
			parentPid = process.pid,
			env = runtime:_normalizeEnv(process.env),
			maxCycles = process.maxCycles,
		})
	end)

	self.syscalls:register("exit", function(_, process, args)
		process.exitCode = args[1] or 0
		process.cpu:halt()
		return process.exitCode
	end)

	self.syscalls:register("lib.return", function(_, process, args)
		process.returnValue = Util.deepCopy(args[1])
		process.exitCode = 0
		process.cpu:halt()
		return process.returnValue
	end)

	self.syscalls:register("halt", function(_, process, args)
		process.exitCode = args[1] or 0
		process.cpu:halt()
		return process.exitCode
	end)
end

function KernelRuntime:_handleSyscall(process, syscall)
	return self.syscalls:invoke(syscall.name, self, process, syscall.args)
end

function KernelRuntime:_createProcess(executable, options)
	options = options or {}

	local pid = self.nextPid
	self.nextPid += 1

	local process = {
		pid = pid,
		path = options.path or executable.name,
		parentPid = options.parentPid,
		argv = self:_normalizeArgv(options.argv, options.preserveArgvRefs == true),
		env = self:_normalizeEnv(options.env),
		exitCode = nil,
		returnValue = nil,
		pendingException = nil,
		maxCycles = options.maxCycles or self.defaultMaxCycles,
		preserveArgvRefs = options.preserveArgvRefs == true,
	}

	if process.env.PWD == nil then
		process.env.PWD = "/"
	end

	local memory = Memory.new(options.memorySize or self.memorySize)
	local layout = Loader.loadExecutable(memory, executable, {})
	local cpu = CPU.new({
		memory = memory,
		entryAddress = layout.entryAddress,
		stackBase = layout.stackBase,
		stackTop = layout.stackTop,
		trace = options.trace == true or self.trace,
		logger = function(message)
			self:_log("[trace] " .. message)
		end,
		onSyscall = function(_, syscall)
			return self:_handleSyscall(process, syscall)
		end,
	})

	process.memory = memory
	process.layout = layout
	process.cpu = cpu
	process.image = executable
	self.processes[pid] = process

	cpu:setRegister("R1", #process.argv)
	cpu:setRegister("R2", Util.deepCopy(process.argv))
	cpu:setRegister("R3", process.path)

	return process
end

function KernelRuntime:_runPreparedProcess(process)
	local ok, resultOrError = pcall(function()
		return process.cpu:run(process.maxCycles)
	end)

	if not ok then
		process.exitCode = process.exitCode or 1
		self:_log(string.format("Process %s crashed: %s", process.path, tostring(resultOrError)))
		self.processes[process.pid] = nil
		return {
			ok = false,
			exitCode = process.exitCode,
			returnValue = process.returnValue,
			error = tostring(resultOrError),
			process = process,
		}
	end

	process.exitCode = process.exitCode or 0
	self.processes[process.pid] = nil
	return {
		ok = true,
		exitCode = process.exitCode,
		returnValue = process.returnValue,
		cycles = resultOrError,
		process = process,
	}
end

function KernelRuntime:spawnImage(executable, options)
	local process = self:_createProcess(executable, options)
	local runner = task and task.spawn or spawn
	runner(function()
		self:_runPreparedProcess(process)
	end)
	return process.pid
end

function KernelRuntime:runImage(executable, options)
	local process = self:_createProcess(executable, options)
	return self:_runPreparedProcess(process)
end

return KernelRuntime
