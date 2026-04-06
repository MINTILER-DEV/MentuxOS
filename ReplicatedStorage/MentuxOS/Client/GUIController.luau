local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = nil
pcall(function()
	UserInputService = game:GetService("UserInputService")
end)

local GUIController = {}
GUIController.__index = GUIController

local function safeSet(instance, property, value)
	pcall(function()
		instance[property] = value
	end)
end

local function disconnectStoredConnection(connection)
	if connection == nil then
		return
	end

	if type(connection) == "table" and connection.connection then
		connection.connection:Disconnect()
		return
	end

	connection:Disconnect()
end

local function cloneList(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

local function extractScopePrefix(id)
	local prefix = tostring(id or ""):match("^(p%d+)::")
	return prefix or "__global"
end

local function asVector2(value)
	if value == nil then
		if type(Vector2) == "table" and type(Vector2.new) == "function" then
			return Vector2.new(0, 0)
		end
		return { X = 0, Y = 0 }
	end

	local x = tonumber(value.X) or 0
	local y = tonumber(value.Y) or 0
	if type(Vector2) == "table" and type(Vector2.new) == "function" then
		return Vector2.new(x, y)
	end
	return { X = x, Y = y }
end

local KEY_CHAR_MAP = {
	Zero = { "0", ")" },
	One = { "1", "!" },
	Two = { "2", "@" },
	Three = { "3", "#" },
	Four = { "4", "$" },
	Five = { "5", "%" },
	Six = { "6", "^" },
	Seven = { "7", "&" },
	Eight = { "8", "*" },
	Nine = { "9", "(" },
	Minus = { "-", "_" },
	Equals = { "=", "+" },
	LeftBracket = { "[", "{" },
	RightBracket = { "]", "}" },
	BackSlash = { "\\", "|" },
	Semicolon = { ";", ":" },
	Quote = { "'", "\"" },
	Comma = { ",", "<" },
	Period = { ".", ">" },
	Slash = { "/", "?" },
	Backquote = { "`", "~" },
}

local function rgb(r, g, b)
	if type(Color3) == "table" and type(Color3.fromRGB) == "function" then
		return Color3.fromRGB(r, g, b)
	end
	if type(Color3) == "table" and type(Color3.new) == "function" then
		return Color3.new(r / 255, g / 255, b / 255)
	end
	return nil
end

local function hexColor(value)
	local hex = tostring(value or ""):gsub("#", "")
	if #hex ~= 6 then
		return nil
	end

	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not r or not g or not b then
		return nil
	end
	return rgb(r, g, b)
end

local function findChildOfClass(instance, className)
	if not instance or type(instance.GetChildren) ~= "function" then
		return nil
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child.ClassName == className then
			return child
		end
	end

	return nil
end

local function themeColor(name)
	local themes = {
		login = rgb(18, 20, 24),
		loginLight = rgb(146, 150, 156),
		desktop = rgb(28, 30, 34),
		desktopLight = rgb(116, 120, 126),
		terminal = rgb(24, 26, 31),
		accent = rgb(208, 125, 52),
		accentSoft = rgb(52, 55, 61),
		panel = rgb(38, 41, 46),
		panelRaised = rgb(46, 49, 55),
		panelDark = rgb(26, 28, 32),
		panelMuted = rgb(43, 46, 52),
		taskbar = rgb(24, 26, 29),
		taskbarSoft = rgb(34, 37, 42),
		taskButton = rgb(45, 48, 54),
		text = rgb(232, 235, 239),
		textMuted = rgb(162, 167, 173),
		textDim = rgb(120, 126, 133),
		stroke = rgb(74, 79, 86),
		strokeStrong = rgb(96, 101, 110),
	}

	if type(name) == "string" and name:sub(1, 1) == "#" then
		return hexColor(name)
	end

	return themes[name] or rgb(40, 44, 50) or name
end

local function countVisualLines(text, estimatedColumns)
	local content = tostring(text or "")
	if content == "" then
		return 1
	end

	local total = 0
	local columns = math.max(8, estimatedColumns or 72)
	for line in string.gmatch(content .. "\n", "([^\n]*)\n") do
		local lineLength = #line
		if lineLength == 0 then
			total += 1
		else
			total += math.max(1, math.ceil(lineLength / columns))
		end
	end

	return math.max(1, total)
end

local function safeCreate(className)
	local ok, instance = pcall(function()
		return Instance.new(className)
	end)
	if ok then
		return instance
	end
	return nil
end

local function parseFillDirection(value)
	if tostring(value or "vertical") == "horizontal" then
		return Enum.FillDirection.Horizontal
	end
	return Enum.FillDirection.Vertical
end

local function parseHorizontalAlignment(value)
	local normalized = tostring(value or "left")
	if normalized == "center" then
		return Enum.HorizontalAlignment.Center
	end
	if normalized == "right" then
		return Enum.HorizontalAlignment.Right
	end
	return Enum.HorizontalAlignment.Left
end

local function parseVerticalAlignment(value)
	local normalized = tostring(value or "top")
	if normalized == "center" then
		return Enum.VerticalAlignment.Center
	end
	if normalized == "bottom" then
		return Enum.VerticalAlignment.Bottom
	end
	return Enum.VerticalAlignment.Top
end

local function isShiftKey(keyCode)
	if not Enum or not Enum.KeyCode then
		return false
	end

	return keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift
end

local function keyCodeToCharacter(keyCode, shifted)
	if not keyCode then
		return nil
	end

	local name = tostring(keyCode.Name or "")
	if name:match("^[A-Z]$") then
		if shifted then
			return name
		end
		return string.lower(name)
	end

	local mapped = KEY_CHAR_MAP[name]
	if mapped then
		return mapped[shifted and 2 or 1]
	end

	if name == "Space" then
		return " "
	end

	if name:match("^Keypad%d$") then
		return name:sub(-1)
	end

	return nil
end

local function parseFont(value)
	if not Enum or not Enum.Font then
		return nil
	end

	local raw = tostring(value or "")
	if raw == "" then
		return nil
	end

	local direct = Enum.Font[raw]
	if direct then
		return direct
	end

	local normalized = raw:gsub("[%s_%-]", ""):lower()
	for _, enumValue in ipairs(Enum.Font:GetEnumItems()) do
		local enumName = tostring(enumValue.Name or "")
		if enumName:gsub("[%s_%-]", ""):lower() == normalized then
			return enumValue
		end
	end

	return nil
end

local function lerp(a, b, alpha)
	return a + ((b - a) * alpha)
end

local function ease(alpha, style)
	local mode = tostring(style or "linear")
	if mode == "outQuad" then
		return 1 - ((1 - alpha) * (1 - alpha))
	end
	if mode == "outCubic" then
		local shifted = 1 - alpha
		return 1 - (shifted * shifted * shifted)
	end
	if mode == "inOutQuad" then
		if alpha < 0.5 then
			return 2 * alpha * alpha
		end
		return 1 - (((-2 * alpha) + 2) ^ 2) / 2
	end
	return alpha
end

local function waitStep(duration)
	local delayTime = math.max(0.001, tonumber(duration) or 0.016)
	if RunService then
		local heartbeat = RunService.Heartbeat or RunService.RenderStepped
		if heartbeat and type(heartbeat.Wait) == "function" then
			local elapsed = 0
			while elapsed < delayTime do
				elapsed += heartbeat:Wait()
			end
			return
		end
	end

	if task and type(task.wait) == "function" then
		task.wait(delayTime)
		return
	end

	wait(delayTime)
end

function GUIController.new(options)
	options = options or {}

	local player = options.player or Players.LocalPlayer
	assert(player, "GUIController requires a local player")

	local playerGui = options.parent or player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
	local eventSignal = Instance.new("BindableEvent")
	local inputEventSignal = Instance.new("BindableEvent")

	local self = setmetatable({
		player = player,
		playerGui = playerGui,
		eventSignal = eventSignal,
		inputEventSignal = inputEventSignal,
		controls = {},
		pendingEvents = {},
		pendingEventsByPrefix = {},
		eventSignalsByPrefix = {},
		pendingInputEvents = {},
		headless = false,
		inputCaptureEnabled = false,
		headlessInputBuffer = "",
		shiftDown = false,
		lastKeyboardSignature = nil,
		lastKeyboardAt = 0,
		lastClickAtById = {},
		globalConnections = {},
		fallbackEvents = cloneList(options.fallbackEvents or {
			{ "click", "login_button", true },
			{ "doubleclick", "desktop_icon_1", true },
		}),
		fallbackInputText = cloneList(options.fallbackInputText or {
			"ls\n",
			"pwd\n",
			"exit\n",
		}),
	}, GUIController)

	local supportsGui = type(Instance) == "table" and type(Instance.new) == "function" and type(UDim2) == "table" and type(UDim2.new) == "function"
	if supportsGui then
		local ok, failure = pcall(function()
			self:_buildRoot()
		end)
		if not ok then
			self.headless = true
			warn("[MentuxOS] GUI unavailable, falling back to headless mode: " .. tostring(failure))
			self.root = {
				Name = "MentuxRoot",
				BackgroundColor3 = "desktop",
			}
		end
	else
		self.headless = true
		self.root = {
			Name = "MentuxRoot",
			BackgroundColor3 = "desktop",
		}
	end

	self:_buildInputHooks()

	return self
end

function GUIController:_buildInputHooks()
	if self.inputHooksReady or not UserInputService then
		return
	end

	self.inputHooksReady = true
	table.insert(self.globalConnections, UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent == true then
			return
		end

		if not Enum or not Enum.UserInputType or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local keyCode = input.KeyCode
		if isShiftKey(keyCode) then
			self.shiftDown = true
			return
		end

		if not self.inputCaptureEnabled then
			return
		end

		local signature = tostring(keyCode and keyCode.Name or "<unknown>")
		local now = os.clock()
		if self.lastKeyboardSignature == signature and (now - self.lastKeyboardAt) <= 0.03 then
			return
		end
		self.lastKeyboardSignature = signature
		self.lastKeyboardAt = now

		if Enum and Enum.KeyCode then
			if keyCode == Enum.KeyCode.Backspace then
				self:_pushInputEvent("backspace", "")
				return
			end
			if keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter then
				self:_pushInputEvent("enter", "")
				return
			end
			if keyCode == Enum.KeyCode.Escape then
				self:_pushInputEvent("escape", "")
				return
			end
			if keyCode == Enum.KeyCode.Tab then
				self:_pushInputEvent("tab", "")
				return
			end
		end

		local character = keyCodeToCharacter(keyCode, self.shiftDown)
		if character and character ~= "" then
			self:_pushInputEvent("char", character)
		end
	end))

	table.insert(self.globalConnections, UserInputService.InputEnded:Connect(function(input)
		if isShiftKey(input.KeyCode) then
			self.shiftDown = false
		end
	end))
end

function GUIController:_buildRoot()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MentuxGui"
	safeSet(screenGui, "ResetOnSpawn", false)
	safeSet(screenGui, "IgnoreGuiInset", true)
	screenGui.Parent = self.playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Position = UDim2.new(0, 0, 0, 0)
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = themeColor("desktop")
	root.BorderSizePixel = 0
	root.Parent = screenGui

	self.screenGui = screenGui
	self.root = root
end

function GUIController:_pushEvent(eventType, id, value)
	local prefix = extractScopePrefix(id)
	local queue = self.pendingEventsByPrefix[prefix]
	if not queue then
		queue = {}
		self.pendingEventsByPrefix[prefix] = queue
	end

	local event = { eventType, id, value }
	local lastPending = queue[#queue]

	if eventType == "submit" and lastPending then
		if lastPending[1] == eventType and lastPending[2] == id and lastPending[3] == value then
			return
		end
	end

	local control = self.controls[id]
	if control and control.kind == "textbox" and (eventType == "submit" or eventType == "change") then
		control.text = tostring(value or "")
		if control.instance then
			control.instance.Text = control.text
		end
	end

	if self.headless then
		table.insert(queue, event)
		return
	end

	table.insert(queue, event)

	local signal = self.eventSignalsByPrefix[prefix]
	if signal == nil and type(Instance) == "table" and type(Instance.new) == "function" then
		local ok, created = pcall(function()
			return Instance.new("BindableEvent")
		end)
		if ok then
			signal = created
			self.eventSignalsByPrefix[prefix] = signal
		end
	end

	if signal then
		signal:Fire(event)
	elseif self.eventSignal then
		self.eventSignal:Fire(event)
	end
end

function GUIController:_pushInputEvent(eventType, value)
	local event = { eventType, value }
	table.insert(self.pendingInputEvents, event)

	if self.headless then
		return
	end

	self.inputEventSignal:Fire(event)
end

function GUIController:_resolveParent(parentId)
	if parentId == nil or parentId == "" then
		return self.root
	end

	local control = self.controls[parentId]
	assert(control and control.instance, "Unknown GUI parent " .. tostring(parentId))
	return control.instance
end

function GUIController:_registerControl(id, kind, instance, parentId)
	local previous = self.controls[id]
	if previous then
		for _, connection in ipairs(previous.connections or {}) do
			disconnectStoredConnection(connection)
		end
		if previous.instance then
			previous.instance:Destroy()
		end
	end

	self.controls[id] = {
		id = id,
		kind = kind,
		instance = instance,
		parentId = parentId,
		connections = {},
		text = "",
		lastClickAt = previous and previous.lastClickAt or 0,
		suppressNextClick = previous and previous.suppressNextClick or false,
	}

	return self.controls[id]
end

function GUIController:_syncTextControl(control)
	if not control then
		return
	end

	if control.content then
		control.content.Text = control.text

		local lineHeight = control.lineHeight or 18
		local estimatedColumns = math.max(24, math.floor((control.widthScale or 0.5) * 88))
		local contentHeight = (countVisualLines(control.text, estimatedColumns) * lineHeight) + 8
		control.content.Size = UDim2.new(1, -12, 0, contentHeight)

		if control.instance then
			safeSet(control.instance, "CanvasSize", UDim2.new(0, 0, 0, contentHeight + 8))

			if type(Vector2) == "table" and type(Vector2.new) == "function" then
				local viewportHeight = 0
				pcall(function()
					viewportHeight = control.instance.AbsoluteSize.Y
				end)
				safeSet(control.instance, "CanvasPosition", Vector2.new(0, math.max(0, contentHeight - viewportHeight)))
			end
		end

		return
	end

	if control.instance then
		control.instance.Text = control.text
	end
end

function GUIController:_applyCorner(instance, radiusScale, radiusOffset)
	local corner = findChildOfClass(instance, "UICorner") or safeCreate("UICorner")
	if not corner then
		return
	end

	safeSet(corner, "CornerRadius", UDim.new(radiusScale or 0, radiusOffset or 12))
	corner.Parent = instance
end

function GUIController:_applyStroke(instance, colorName, thickness, transparency)
	local stroke = findChildOfClass(instance, "UIStroke") or safeCreate("UIStroke")
	if not stroke then
		return
	end

	safeSet(stroke, "Color", themeColor(colorName or "stroke"))
	safeSet(stroke, "Thickness", thickness or 1)
	safeSet(stroke, "Transparency", transparency or 0)
	stroke.Parent = instance
end

function GUIController:_applyPadding(instance, left, top, right, bottom)
	local padding = findChildOfClass(instance, "UIPadding") or safeCreate("UIPadding")
	if not padding then
		return
	end

	safeSet(padding, "PaddingLeft", UDim.new(left or 0, 0))
	safeSet(padding, "PaddingTop", UDim.new(top or 0, 0))
	safeSet(padding, "PaddingRight", UDim.new(right or 0, 0))
	safeSet(padding, "PaddingBottom", UDim.new(bottom or 0, 0))
	padding.Parent = instance
end

function GUIController:reset()
	for _, control in pairs(self.controls) do
		for _, connection in ipairs(control.connections or {}) do
			disconnectStoredConnection(connection)
		end
	end
	self.controls = {}
	table.clear(self.pendingEvents)
	table.clear(self.pendingInputEvents)

	if self.headless then
		return true
	end

	for _, child in ipairs(self.root:GetChildren()) do
		child:Destroy()
	end

	return true
end

function GUIController:resetScope(prefix)
	local scopedPrefix = tostring(prefix or "")
	if scopedPrefix == "" then
		return self:reset()
	end

	local destroyIds = {}
	for id, control in pairs(self.controls) do
		if tostring(id):sub(1, #scopedPrefix + 2) == (scopedPrefix .. "::") then
			if not control.parentId or tostring(control.parentId):sub(1, #scopedPrefix + 2) ~= (scopedPrefix .. "::") then
				table.insert(destroyIds, id)
			end
		end
	end

	table.sort(destroyIds)
	for _, id in ipairs(destroyIds) do
		self:destroy(id)
	end

	local queue = self.pendingEventsByPrefix[scopedPrefix]
	if queue then
		table.clear(queue)
	end

	return true
end

function GUIController:setBackground(themeName)
	if self.headless then
		self.root.BackgroundColor3 = themeColor(themeName)
		return true
	end

	self.root.BackgroundColor3 = themeColor(themeName)
	return true
end

function GUIController:_resolveControlInstance(id)
	if id == nil or id == "" or id == "__root" or id == "root" then
		return self.root, nil
	end

	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	return control.instance, control
end

function GUIController:createWindow(id, title, x, y, width, height)
	if self.headless then
		local control = self:_registerControl(id, "window", nil, "")
		control.text = tostring(title or "")
		return true
	end

	local frame = Instance.new("Frame")
	frame.Name = id
	frame.Position = UDim2.new(x or 0, 0, y or 0, 0)
	frame.Size = UDim2.new(width or 0.5, 0, height or 0.5, 0)
	frame.BackgroundColor3 = themeColor("panel")
	frame.BorderSizePixel = 0
	safeSet(frame, "BackgroundTransparency", 0.03)
	safeSet(frame, "ClipsDescendants", true)
	frame.Parent = self.root
	self:_applyCorner(frame, 0, 6)
	self:_applyStroke(frame, "stroke", 1, 0.15)

	local titleBar = Instance.new("TextLabel")
	titleBar.Name = "Title"
	titleBar.BackgroundColor3 = themeColor("taskbarSoft")
	titleBar.BorderSizePixel = 0
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.Size = UDim2.new(1, 0, 0, 38)
	titleBar.Font = Enum.Font.Code
	titleBar.TextSize = 17
	titleBar.TextXAlignment = Enum.TextXAlignment.Left
	titleBar.TextColor3 = Color3.fromRGB(240, 244, 248)
	titleBar.Text = "  " .. tostring(title or id)
	titleBar.Parent = frame

	local control = self:_registerControl(id, "window", frame, "")
	control.text = tostring(title or "")
	control.titleBar = titleBar
	return true
end

function GUIController:createPanel(id, parentId, x, y, width, height, tone)
	if self.headless then
		return self:_registerControl(id, "panel", nil, parentId) ~= nil
	end

	local panel = Instance.new("Frame")
	panel.Name = id
	panel.Position = UDim2.new(x or 0, 0, y or 0, 0)
	panel.Size = UDim2.new(width or 0.4, 0, height or 0.2, 0)
	panel.BackgroundColor3 = themeColor(tone or "panel")
	panel.BorderSizePixel = 0
	panel.Parent = self:_resolveParent(parentId)
	self:_applyCorner(panel, 0, 4)
	self:_applyStroke(panel, "stroke", 1, 0.18)

	self:_registerControl(id, "panel", panel, parentId)
	return true
end

function GUIController:createLabel(id, parentId, text, x, y, width, height)
	if self.headless then
		local control = self:_registerControl(id, "label", nil, parentId)
		control.text = tostring(text or "")
		return true
	end

	local label = Instance.new("TextLabel")
	label.Name = id
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(x or 0, 0, y or 0, 0)
	label.Size = UDim2.new(width or 0.4, 0, height or 0.08, 0)
	label.Font = Enum.Font.Code
	label.TextWrapped = true
	label.TextSize = 17
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = themeColor("text")
	label.Text = tostring(text or "")
	label.Parent = self:_resolveParent(parentId)

	local control = self:_registerControl(id, "label", label, parentId)
	control.text = tostring(text or "")
	return true
end

function GUIController:createRichTextArea(id, parentId, text, x, y, width, height)
	if self.headless then
		local control = self:_registerControl(id, "richtext", nil, parentId)
		control.text = tostring(text or "")
		return true
	end

	local ok, container = pcall(function()
		return Instance.new("ScrollingFrame")
	end)
	if not ok then
		local fallback = Instance.new("TextLabel")
		fallback.Name = id
		fallback.BackgroundColor3 = themeColor("panelDark")
		fallback.BorderSizePixel = 1
		fallback.Position = UDim2.new(x or 0, 0, y or 0, 0)
		fallback.Size = UDim2.new(width or 0.5, 0, height or 0.4, 0)
		fallback.Font = Enum.Font.Code
		fallback.TextWrapped = true
		fallback.TextSize = 16
		fallback.TextXAlignment = Enum.TextXAlignment.Left
		fallback.TextYAlignment = Enum.TextYAlignment.Top
		fallback.TextColor3 = themeColor("text")
		fallback.Text = tostring(text or "")
		safeSet(fallback, "RichText", true)
		fallback.Parent = self:_resolveParent(parentId)

		local fallbackControl = self:_registerControl(id, "richtext", fallback, parentId)
		fallbackControl.text = tostring(text or "")
		return true
	end

	container.Name = id
	container.Position = UDim2.new(x or 0, 0, y or 0, 0)
	container.Size = UDim2.new(width or 0.5, 0, height or 0.4, 0)
	container.BackgroundColor3 = themeColor("panelDark")
	container.BorderSizePixel = 0
	safeSet(container, "ScrollBarThickness", 8)
	safeSet(container, "CanvasSize", UDim2.new(0, 0, 0, 0))
	if Enum and Enum.AutomaticSize then
		safeSet(container, "AutomaticCanvasSize", Enum.AutomaticSize.Y)
	end
	container.Parent = self:_resolveParent(parentId)
	self:_applyCorner(container, 0, 4)
	self:_applyStroke(container, "stroke", 1, 0.12)

	local label = Instance.new("TextLabel")
	label.Name = "Content"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 6, 0, 4)
	label.Size = UDim2.new(1, -12, 0, 24)
	label.Font = Enum.Font.Code
	label.TextWrapped = true
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = themeColor("text")
	label.Text = tostring(text or "")
	safeSet(label, "RichText", true)
	label.Parent = container

	local control = self:_registerControl(id, "richtext", container, parentId)
	control.content = label
	control.widthScale = width or 0.5
	control.lineHeight = 18
	control.text = tostring(text or "")
	self:_syncTextControl(control)
	return true
end

function GUIController:createButton(id, parentId, text, x, y, width, height)
	if self.headless then
		local control = self:_registerControl(id, "button", nil, parentId)
		control.text = tostring(text or "")
		return true
	end

	local button = Instance.new("TextButton")
	button.Name = id
	button.Position = UDim2.new(x or 0, 0, y or 0, 0)
	button.Size = UDim2.new(width or 0.2, 0, height or 0.1, 0)
	button.BackgroundColor3 = themeColor("taskButton")
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.Code
	button.TextSize = 17
	button.TextColor3 = themeColor("text")
	button.Text = tostring(text or "")
	button.Parent = self:_resolveParent(parentId)
	self:_applyCorner(button, 0, 3)
	self:_applyStroke(button, "strokeStrong", 1, 0.25)

	local control = self:_registerControl(id, "button", button, parentId)
	control.text = tostring(text or "")
	control.lastClickAt = self.lastClickAtById[id] or 0
	control.suppressNextClick = false
	table.insert(control.connections, button.MouseButton1Click:Connect(function()
		if control.suppressNextClick == true then
			control.suppressNextClick = false
			return
		end

		local now = os.clock()
		local lastClickAt = self.lastClickAtById[id] or control.lastClickAt or 0
		if (now - lastClickAt) <= 0.35 then
			control.lastClickAt = 0
			self.lastClickAtById[id] = 0
			self:_pushEvent("doubleclick", id, true)
		else
			control.lastClickAt = now
			self.lastClickAtById[id] = now
			self:_pushEvent("click", id, true)
		end
	end))
	return true
end

function GUIController:enableDrag(id, targetId)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	local target = self.controls[targetId or id]
	assert(target, "Unknown drag target " .. tostring(targetId or id))

	if self.headless or not UserInputService then
		control.dragTargetId = target.id
		return true
	end

	local handle = control.instance
	local targetInstance = target.instance
	if not handle or not targetInstance then
		return true
	end

	for index = #control.connections, 1, -1 do
		local connection = control.connections[index]
		if type(connection) == "table" and connection.__mentuxDrag == true then
			if connection.connection then
				connection.connection:Disconnect()
			end
			table.remove(control.connections, index)
		end
	end

	local dragging = false
	local dragInput = nil
	local dragStartPos = nil
	local dragStartTargetAbsolute = nil
	local moved = false

	local function rootSize()
		local width = 1
		local height = 1
		pcall(function()
			width = math.max(1, self.root.AbsoluteSize.X)
			height = math.max(1, self.root.AbsoluteSize.Y)
		end)
		return width, height
	end

	local function rootAbsolutePosition()
		local position = asVector2(nil)
		pcall(function()
			position = asVector2(self.root.AbsolutePosition)
		end)
		return position
	end

	local function attach(connection)
		table.insert(control.connections, {
			__mentuxDrag = true,
			connection = connection,
		})
	end

	attach(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStartPos = asVector2(input.Position)
			dragStartTargetAbsolute = asVector2(targetInstance.AbsolutePosition)
			moved = false
		end
	end))

	attach(handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))

	attach(UserInputService.InputChanged:Connect(function(input)
		if dragging and dragInput and input == dragInput and dragStartTargetAbsolute and dragStartPos then
			local currentPos = asVector2(input.Position)
			local delta = currentPos - dragStartPos
			if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
				moved = true
			end

			local rootWidth, rootHeight = rootSize()
			local rootTopLeft = rootAbsolutePosition()
			local frameWidth = math.max(1, targetInstance.AbsoluteSize.X)
			local frameHeight = math.max(1, targetInstance.AbsoluteSize.Y)
			local topLeft = dragStartTargetAbsolute + delta
			local maxX = math.max(0, 1 - (frameWidth / rootWidth))
			local maxY = math.max(0, 1 - (frameHeight / rootHeight))
			local newX = math.max(0, math.min(maxX, (topLeft.X - rootTopLeft.X) / rootWidth))
			local newY = math.max(0, math.min(maxY, (topLeft.Y - rootTopLeft.Y) / rootHeight))
			targetInstance.Position = UDim2.new(newX, 0, newY, 0)
		end
	end))

	attach(UserInputService.InputEnded:Connect(function(input)
		if dragging and dragInput and input == dragInput then
			dragging = false
			if moved then
				if control.kind == "button" then
					control.suppressNextClick = true
				end
				local position = targetInstance.Position
				self:_pushEvent("dragend", id, { position.X.Scale, position.Y.Scale })
			end
			dragInput = nil
			dragStartPos = nil
			dragStartTargetAbsolute = nil
			moved = false
		end
	end))

	control.dragTargetId = target.id
	return true
end

function GUIController:setDraggable(id, enabled, targetId)
	if enabled == false then
		return true
	end
	return self:enableDrag(id, targetId)
end

function GUIController:createTextBox(id, parentId, placeholder, text, x, y, width, height, secret, multiline)
	if self.headless then
		local control = self:_registerControl(id, "textbox", nil, parentId)
		control.text = tostring(text or "")
		return true
	end

	local textBox = Instance.new("TextBox")
	textBox.Name = id
	textBox.Position = UDim2.new(x or 0, 0, y or 0, 0)
	textBox.Size = UDim2.new(width or 0.4, 0, height or 0.1, 0)
	textBox.BackgroundColor3 = themeColor("panelRaised")
	textBox.BorderSizePixel = 0
	textBox.ClearTextOnFocus = false
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 17
	textBox.PlaceholderText = tostring(placeholder or "")
	textBox.Text = tostring(text or "")
	-- Use generic protected set because RLE may not expose IsPassword.
	safeSet(textBox, "TextXAlignment", Enum.TextXAlignment.Left)
	safeSet(textBox, "TextYAlignment", Enum.TextYAlignment.Top)
	safeSet(textBox, "TextWrapped", multiline == true)
	safeSet(textBox, "MultiLine", multiline == true)
	safeSet(textBox, "TextColor3", themeColor("text"))
	safeSet(textBox, "PlaceholderColor3", themeColor("textDim"))
	safeSet(textBox, "IsPassword", secret == true)
	textBox.Parent = self:_resolveParent(parentId)
	self:_applyCorner(textBox, 0, 3)
	self:_applyStroke(textBox, "stroke", 1, 0.1)

	local changeSignalOk, changeSignal = pcall(function()
		return textBox:GetPropertyChangedSignal("Text")
	end)

	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:_pushEvent("submit", id, textBox.Text)
		end
	end)

	local control = self:_registerControl(id, "textbox", textBox, parentId)
	control.text = tostring(text or "")
	if changeSignalOk and changeSignal then
		control.connections = control.connections or {}
		table.insert(control.connections, changeSignal:Connect(function()
			if control.suppressChange == true then
				return
			end
			self:_pushEvent("change", id, textBox.Text)
		end))
	end
	return true
end

function GUIController:createScrollFrame(id, parentId, x, y, width, height, canvasHeight)
	if self.headless then
		return self:_registerControl(id, "scrollframe", nil, parentId) ~= nil
	end

	local ok, frame = pcall(function()
		return Instance.new("ScrollingFrame")
	end)
	if not ok then
		local fallback = Instance.new("Frame")
		fallback.Name = id
		fallback.Position = UDim2.new(x or 0, 0, y or 0, 0)
		fallback.Size = UDim2.new(width or 0.5, 0, height or 0.3, 0)
		fallback.BackgroundColor3 = themeColor("panelDark")
		fallback.BorderSizePixel = 1
		fallback.ClipsDescendants = true
		fallback.Parent = self:_resolveParent(parentId)
		self:_registerControl(id, "scrollframe", fallback, parentId)
		return true
	end

	frame.Name = id
	frame.Position = UDim2.new(x or 0, 0, y or 0, 0)
	frame.Size = UDim2.new(width or 0.5, 0, height or 0.3, 0)
	frame.BackgroundColor3 = themeColor("panelDark")
	frame.BorderSizePixel = 1
	safeSet(frame, "ScrollBarThickness", 8)
	safeSet(frame, "CanvasSize", UDim2.new(0, 0, 0, math.floor((canvasHeight or height or 0.3) * 600)))
	if Enum and Enum.AutomaticSize then
		safeSet(frame, "AutomaticCanvasSize", Enum.AutomaticSize.Y)
	end
	frame.Parent = self:_resolveParent(parentId)
	self:_applyCorner(frame, 0, 4)
	self:_applyStroke(frame, "stroke", 1, 0.15)

	self:_registerControl(id, "scrollframe", frame, parentId)
	return true
end

function GUIController:createTextArea(id, parentId, text, x, y, width, height)
	if self.headless then
		local control = self:_registerControl(id, "textarea", nil, parentId)
		control.text = tostring(text or "")
		return true
	end

	local ok, container = pcall(function()
		return Instance.new("ScrollingFrame")
	end)
	if not ok then
		local label = Instance.new("TextLabel")
		label.Name = id
		label.BackgroundColor3 = themeColor("panelDark")
		label.BorderSizePixel = 1
		label.Position = UDim2.new(x or 0, 0, y or 0, 0)
		label.Size = UDim2.new(width or 0.5, 0, height or 0.4, 0)
		label.Font = Enum.Font.Code
		label.TextWrapped = true
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = themeColor("text")
		label.Text = tostring(text or "")
		label.Parent = self:_resolveParent(parentId)

		local fallbackControl = self:_registerControl(id, "textarea", label, parentId)
		fallbackControl.text = tostring(text or "")
		return true
	end

	container.Name = id
	container.Position = UDim2.new(x or 0, 0, y or 0, 0)
	container.Size = UDim2.new(width or 0.5, 0, height or 0.4, 0)
	container.BackgroundColor3 = themeColor("panelDark")
	container.BorderSizePixel = 0
	safeSet(container, "ScrollBarThickness", 8)
	safeSet(container, "CanvasSize", UDim2.new(0, 0, 0, 0))
	if Enum and Enum.AutomaticSize then
		safeSet(container, "AutomaticCanvasSize", Enum.AutomaticSize.Y)
	end
	container.Parent = self:_resolveParent(parentId)
	self:_applyCorner(container, 0, 4)
	self:_applyStroke(container, "stroke", 1, 0.12)

	local label = Instance.new("TextLabel")
	label.Name = "Content"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 6, 0, 4)
	label.Size = UDim2.new(1, -12, 0, 24)
	label.Font = Enum.Font.Code
	label.TextWrapped = true
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = themeColor("text")
	label.Text = tostring(text or "")
	label.Parent = container

	local control = self:_registerControl(id, "textarea", container, parentId)
	control.content = label
	control.widthScale = width or 0.5
	control.lineHeight = 18
	control.text = tostring(text or "")
	self:_syncTextControl(control)
	return true
end

function GUIController:setAnchorPoint(id, x, y)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if control.instance and type(Vector2) == "table" and type(Vector2.new) == "function" then
		safeSet(control.instance, "AnchorPoint", Vector2.new(tonumber(x) or 0, tonumber(y) or 0))
	end
	return true
end

function GUIController:setBackgroundColor(id, colorName)
	local instance = self:_resolveControlInstance(id)
	if instance then
		safeSet(instance, "BackgroundColor3", themeColor(colorName))
	end
	return true
end

function GUIController:setTextColor(id, colorName)
	local _, control = self:_resolveControlInstance(id)
	if control and control.instance then
		safeSet(control.instance, "TextColor3", themeColor(colorName))
	end
	if control and control.content then
		safeSet(control.content, "TextColor3", themeColor(colorName))
	end
	if control and control.label then
		safeSet(control.label, "TextColor3", themeColor(colorName))
	end
	if control and control.glyph then
		safeSet(control.glyph, "TextColor3", themeColor(colorName))
	end
	return true
end

function GUIController:setStrokeColor(id, colorName)
	local instance = self:_resolveControlInstance(id)
	if instance then
		self:_applyStroke(instance, colorName or "stroke", 1, 0)
	end
	return true
end

function GUIController:setSize(id, width, height)
	local instance = self:_resolveControlInstance(id)
	if instance then
		safeSet(instance, "Size", UDim2.new(tonumber(width) or 0, 0, tonumber(height) or 0, 0))
	end
	return true
end

function GUIController:setPosition(id, x, y)
	local instance = self:_resolveControlInstance(id)
	if instance then
		safeSet(instance, "Position", UDim2.new(tonumber(x) or 0, 0, tonumber(y) or 0, 0))
	end
	return true
end

function GUIController:setVisible(id, visible)
	local instance = self:_resolveControlInstance(id)
	if instance then
		safeSet(instance, "Visible", visible == true)
	end
	return true
end

function GUIController:setParent(id, parentId)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	control.parentId = parentId
	if control.instance then
		control.instance.Parent = self:_resolveParent(parentId)
	end
	return true
end

function GUIController:setZIndex(id, zIndex)
	local _, control = self:_resolveControlInstance(id)
	local value = tonumber(zIndex) or 1
	if control and control.instance then
		safeSet(control.instance, "ZIndex", value)
	end
	if control and control.content then
		safeSet(control.content, "ZIndex", value)
	end
	if control and control.label then
		safeSet(control.label, "ZIndex", value)
	end
	if control and control.glyph then
		safeSet(control.glyph, "ZIndex", value)
	end
	if control and control.button then
		safeSet(control.button, "ZIndex", value)
	end
	return true
end

function GUIController:setFont(id, fontName)
	local _, control = self:_resolveControlInstance(id)
	local font = parseFont(fontName)
	if not font then
		return false
	end
	if control and control.instance then
		safeSet(control.instance, "Font", font)
	end
	if control and control.content then
		safeSet(control.content, "Font", font)
	end
	if control and control.label then
		safeSet(control.label, "Font", font)
	end
	if control and control.glyph then
		safeSet(control.glyph, "Font", font)
	end
	return true
end

function GUIController:setTextSize(id, textSize)
	local _, control = self:_resolveControlInstance(id)
	local value = tonumber(textSize) or 16
	if control and control.instance then
		safeSet(control.instance, "TextSize", value)
	end
	if control and control.content then
		safeSet(control.content, "TextSize", value)
	end
	if control and control.label then
		safeSet(control.label, "TextSize", value)
	end
	if control and control.glyph then
		safeSet(control.glyph, "TextSize", value)
	end
	return true
end

function GUIController:setImage(id, imageValue)
	local _, control = self:_resolveControlInstance(id)
	if control and control.instance then
		safeSet(control.instance, "Image", tostring(imageValue or ""))
	end
	if control and control.content then
		safeSet(control.content, "Image", tostring(imageValue or ""))
	end
	return true
end

function GUIController:tween(id, propertyName, a, b, duration, easingName, steps)
	local _, control = self:_resolveControlInstance(id)
	if self.headless or not control or not control.instance then
		return true
	end

	local instance = control.instance
	local property = tostring(propertyName or "position")
	local totalSteps = math.max(1, tonumber(steps) or 10)
	local totalDuration = tonumber(duration) or 0.18

	local function apply(alpha)
		local eased = ease(alpha, easingName)
		if property == "position" then
			local fromX = tonumber(instance.Position.X.Scale) or 0
			local fromY = tonumber(instance.Position.Y.Scale) or 0
			local toX = tonumber(a) or fromX
			local toY = tonumber(b) or fromY
			safeSet(instance, "Position", UDim2.new(lerp(fromX, toX, eased), 0, lerp(fromY, toY, eased), 0))
			return
		end

		if property == "size" then
			local fromW = tonumber(instance.Size.X.Scale) or 0
			local fromH = tonumber(instance.Size.Y.Scale) or 0
			local toW = tonumber(a) or fromW
			local toH = tonumber(b) or fromH
			safeSet(instance, "Size", UDim2.new(lerp(fromW, toW, eased), 0, lerp(fromH, toH, eased), 0))
			return
		end

		local robloxProperty = nil
		if property == "backgroundTransparency" then
			robloxProperty = "BackgroundTransparency"
		elseif property == "textTransparency" then
			robloxProperty = "TextTransparency"
		end

		if robloxProperty then
			local fromValue = tonumber(instance[robloxProperty]) or 0
			local toValue = tonumber(a) or fromValue
			safeSet(instance, robloxProperty, lerp(fromValue, toValue, eased))
			if control.content and robloxProperty == "TextTransparency" then
				safeSet(control.content, robloxProperty, lerp(fromValue, toValue, eased))
			end
		end
	end

	for index = 0, totalSteps do
		apply(index / totalSteps)
		if index < totalSteps then
			waitStep(totalDuration / totalSteps)
		end
	end

	return true
end

function GUIController:tweenWithPreset(id, preset)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if self.headless or not control.instance or type(preset) ~= "table" then
		return true
	end

	local property = tostring(preset.property or "position")
	local steps = math.max(1, tonumber(preset.steps) or 10)
	local duration = tonumber(preset.duration) or 0.18

	local function apply(alpha)
		local eased = ease(alpha, preset.easing)
		if property == "position" then
			local fromX = tonumber(preset.fromX) or 0
			local fromY = tonumber(preset.fromY) or 0
			local toX = tonumber(preset.toX) or fromX
			local toY = tonumber(preset.toY) or fromY
			safeSet(control.instance, "Position", UDim2.new(lerp(fromX, toX, eased), 0, lerp(fromY, toY, eased), 0))
			return
		end

		if property == "size" then
			local fromW = tonumber(preset.fromW) or 0.2
			local fromH = tonumber(preset.fromH) or 0.2
			local toW = tonumber(preset.toW) or fromW
			local toH = tonumber(preset.toH) or fromH
			safeSet(control.instance, "Size", UDim2.new(lerp(fromW, toW, eased), 0, lerp(fromH, toH, eased), 0))
			return
		end

		if property == "backgroundTransparency" then
			local fromValue = tonumber(preset.fromValue) or 0
			local toValue = tonumber(preset.toValue) or fromValue
			safeSet(control.instance, "BackgroundTransparency", lerp(fromValue, toValue, eased))
		end
	end

	for index = 0, steps do
		apply(index / steps)
		if index < steps then
			waitStep(duration / steps)
		end
	end

	return true
end

function GUIController:setCornerRadius(id, radiusOffset)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if control.instance then
		self:_applyCorner(control.instance, 0, tonumber(radiusOffset) or 14)
	end
	return true
end

function GUIController:applyStylePreset(id, preset)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if type(preset) ~= "table" then
		return false
	end

	local instance = control.instance
	if instance then
		if preset.backgroundColor then
			safeSet(instance, "BackgroundColor3", themeColor(preset.backgroundColor))
		end
		if preset.backgroundTransparency ~= nil then
			safeSet(instance, "BackgroundTransparency", tonumber(preset.backgroundTransparency) or 0)
		end
		if preset.textColor then
			safeSet(instance, "TextColor3", themeColor(preset.textColor))
		end
		if preset.textTransparency ~= nil then
			safeSet(instance, "TextTransparency", tonumber(preset.textTransparency) or 0)
		end
		if preset.cornerRadius ~= nil then
			self:_applyCorner(instance, 0, tonumber(preset.cornerRadius) or 0)
		end
		if preset.strokeColor or preset.strokeTransparency or preset.strokeThickness then
			self:_applyStroke(instance, preset.strokeColor or "stroke", tonumber(preset.strokeThickness) or 1, tonumber(preset.strokeTransparency) or 0)
		end
	end

	if control.content then
		if preset.contentTextColor then
			safeSet(control.content, "TextColor3", themeColor(preset.contentTextColor))
		elseif preset.textColor then
			safeSet(control.content, "TextColor3", themeColor(preset.textColor))
		end
		if preset.contentTextTransparency ~= nil then
			safeSet(control.content, "TextTransparency", tonumber(preset.contentTextTransparency) or 0)
		elseif preset.textTransparency ~= nil then
			safeSet(control.content, "TextTransparency", tonumber(preset.textTransparency) or 0)
		end
	end

	if control.titleBar then
		if preset.titleBackgroundColor then
			safeSet(control.titleBar, "BackgroundColor3", themeColor(preset.titleBackgroundColor))
		end
		if preset.titleTextColor then
			safeSet(control.titleBar, "TextColor3", themeColor(preset.titleTextColor))
		end
		if preset.titleTransparency ~= nil then
			safeSet(control.titleBar, "BackgroundTransparency", tonumber(preset.titleTransparency) or 0)
		end
	end

	if control.label and preset.labelTextColor then
		safeSet(control.label, "TextColor3", themeColor(preset.labelTextColor))
	end
	if control.glyph and preset.glyphTextColor then
		safeSet(control.glyph, "TextColor3", themeColor(preset.glyphTextColor))
	end
	if control.button and preset.hitboxTransparency ~= nil then
		safeSet(control.button, "BackgroundTransparency", tonumber(preset.hitboxTransparency) or 0)
	end

	return true
end

function GUIController:addPadding(id, left, top, right, bottom)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if control.instance then
		self:_applyPadding(control.instance, tonumber(left) or 0, tonumber(top) or 0, tonumber(right) or 0, tonumber(bottom) or 0)
	end
	return true
end

function GUIController:addListLayout(id, direction, paddingScale, horizontalAlignment, verticalAlignment)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if self.headless or not control.instance then
		return true
	end

	local layout = safeCreate("UIListLayout")
	if not layout then
		return true
	end

	safeSet(layout, "FillDirection", parseFillDirection(direction))
	safeSet(layout, "Padding", UDim.new(tonumber(paddingScale) or 0.01, 0))
	safeSet(layout, "HorizontalAlignment", parseHorizontalAlignment(horizontalAlignment))
	safeSet(layout, "VerticalAlignment", parseVerticalAlignment(verticalAlignment))
	layout.Parent = control.instance
	return true
end

function GUIController:setBackgroundTransparency(id, transparency)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	local value = tonumber(transparency) or 0
	if control.instance then
		safeSet(control.instance, "BackgroundTransparency", value)
	end
	return true
end

function GUIController:setTextTransparency(id, transparency)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	local value = tonumber(transparency) or 0
	if control.instance then
		safeSet(control.instance, "TextTransparency", value)
	end
	if control.content then
		safeSet(control.content, "TextTransparency", value)
	end
	return true
end

function GUIController:setText(id, text)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	control.text = tostring(text or "")
	if control.kind == "textbox" and control.instance then
		control.suppressChange = true
		control.instance.Text = control.text
		control.suppressChange = false
		if self.headless then
			print("[MentuxGUI:" .. tostring(id) .. "] " .. control.text)
		end
		return true
	end
	self:_syncTextControl(control)
	if self.headless then
		print("[MentuxGUI:" .. tostring(id) .. "] " .. control.text)
	end
	return true
end

function GUIController:appendText(id, text)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	local chunk = tostring(text or "")
	if control.text ~= "" then
		control.text ..= "\n" .. chunk
	else
		control.text = chunk
	end
	self:_syncTextControl(control)
	if self.headless then
		print("[MentuxGUI:" .. tostring(id) .. "] " .. chunk)
	end
	return true
end

function GUIController:getText(id)
	local control = assert(self.controls[id], "Unknown GUI control " .. tostring(id))
	if control.instance and control.kind == "textbox" then
		control.text = control.instance.Text
	end
	return control.text
end

function GUIController:destroy(id)
	local control = self.controls[id]
	if not control then
		return false
	end

	for childId, child in pairs(self.controls) do
		if child.parentId == id then
			self:destroy(childId)
		end
	end

	if control.instance then
		control.instance:Destroy()
	end
	for _, connection in ipairs(control.connections or {}) do
		disconnectStoredConnection(connection)
	end
	self.controls[id] = nil
	return true
end

function GUIController:waitEvent()
	local globalQueue = self.pendingEventsByPrefix.__global
	if globalQueue and #globalQueue > 0 then
		return table.remove(globalQueue, 1)
	end

	if self.headless and #self.fallbackEvents > 0 then
		local event = table.remove(self.fallbackEvents, 1)
		self:_pushEvent(event[1], event[2], event[3])
		return table.remove(self.pendingEvents, 1)
	end

	if self.eventSignal and self.eventSignal.Event and type(self.eventSignal.Event.Wait) == "function" then
		local event = self.eventSignal.Event:Wait()
		globalQueue = self.pendingEventsByPrefix.__global
		if globalQueue and #globalQueue > 0 then
			return table.remove(globalQueue, 1)
		end
		return event
	end

	while true do
		globalQueue = self.pendingEventsByPrefix.__global
		if globalQueue and #globalQueue > 0 then
			return table.remove(globalQueue, 1)
		end

		if self.headless and #self.fallbackEvents > 0 then
			local event = table.remove(self.fallbackEvents, 1)
			self:_pushEvent(event[1], event[2], event[3])
			return table.remove(self.pendingEvents, 1)
		end

		waitStep(0.05)
	end
end

function GUIController:waitEventForPrefix(prefix)
	local scopedPrefix = tostring(prefix or "__global")
	local queue = self.pendingEventsByPrefix[scopedPrefix]
	if queue and #queue > 0 then
		return table.remove(queue, 1)
	end

	if self.headless and #self.fallbackEvents > 0 then
		local event = table.remove(self.fallbackEvents, 1)
		self:_pushEvent(event[1], scopedPrefix .. "::" .. tostring(event[2]), event[3])
		queue = self.pendingEventsByPrefix[scopedPrefix]
		if queue and #queue > 0 then
			return table.remove(queue, 1)
		end
	end

	local signal = self.eventSignalsByPrefix[scopedPrefix]
	if signal == nil and type(Instance) == "table" and type(Instance.new) == "function" then
		local ok, created = pcall(function()
			return Instance.new("BindableEvent")
		end)
		if ok then
			signal = created
			self.eventSignalsByPrefix[scopedPrefix] = signal
		end
	end

	if signal and signal.Event and type(signal.Event.Wait) == "function" then
		local event = signal.Event:Wait()
		queue = self.pendingEventsByPrefix[scopedPrefix]
		if queue and #queue > 0 then
			return table.remove(queue, 1)
		end
		return event
	end

	while true do
		queue = self.pendingEventsByPrefix[scopedPrefix]
		if queue and #queue > 0 then
			return table.remove(queue, 1)
		end
		waitStep(0.05)
	end
end

function GUIController:startInputCapture()
	self.inputCaptureEnabled = true
	self.lastKeyboardSignature = nil
	self.lastKeyboardAt = 0
	return true
end

function GUIController:stopInputCapture()
	self.inputCaptureEnabled = false
	self.lastKeyboardSignature = nil
	self.lastKeyboardAt = 0
	return true
end

function GUIController:clearInputEvents()
	table.clear(self.pendingInputEvents)
	self.headlessInputBuffer = ""
	self.lastKeyboardSignature = nil
	self.lastKeyboardAt = 0
	return true
end

function GUIController:waitInputEvent()
	if #self.pendingInputEvents > 0 then
		return table.remove(self.pendingInputEvents, 1)
	end

	if self.headless and self.inputCaptureEnabled then
		if self.headlessInputBuffer == "" and #self.fallbackInputText > 0 then
			self.headlessInputBuffer = table.remove(self.fallbackInputText, 1)
		end

		if self.headlessInputBuffer ~= "" then
			local character = self.headlessInputBuffer:sub(1, 1)
			self.headlessInputBuffer = self.headlessInputBuffer:sub(2)
			if character == "\n" then
				self:_pushInputEvent("enter", "")
			elseif character == "\b" then
				self:_pushInputEvent("backspace", "")
			else
				self:_pushInputEvent("char", character)
			end
			return table.remove(self.pendingInputEvents, 1)
		end
	end

	if self.inputEventSignal and self.inputEventSignal.Event and type(self.inputEventSignal.Event.Wait) == "function" then
		local event = self.inputEventSignal.Event:Wait()
		if #self.pendingInputEvents > 0 then
			return table.remove(self.pendingInputEvents, 1)
		end
		return event
	end

	while true do
		if #self.pendingInputEvents > 0 then
			return table.remove(self.pendingInputEvents, 1)
		end

		if self.headless and self.inputCaptureEnabled then
			if self.headlessInputBuffer == "" and #self.fallbackInputText > 0 then
				self.headlessInputBuffer = table.remove(self.fallbackInputText, 1)
			end

			if self.headlessInputBuffer ~= "" then
				local character = self.headlessInputBuffer:sub(1, 1)
				self.headlessInputBuffer = self.headlessInputBuffer:sub(2)
				if character == "\n" then
					self:_pushInputEvent("enter", "")
				elseif character == "\b" then
					self:_pushInputEvent("backspace", "")
				else
					self:_pushInputEvent("char", character)
				end
				return table.remove(self.pendingInputEvents, 1)
			end
		end

		waitStep(0.05)
	end
end

function GUIController:destroyAll()
	for _, connection in ipairs(self.globalConnections or {}) do
		connection:Disconnect()
	end
	if self.screenGui then
		self.screenGui:Destroy()
	end
	if self.eventSignal then
		self.eventSignal:Destroy()
	end
	if self.inputEventSignal then
		self.inputEventSignal:Destroy()
	end
end

return GUIController
