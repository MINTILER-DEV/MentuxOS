local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Main = require(ReplicatedStorage:WaitForChild("MentuxOS"):WaitForChild("Main"))
local GUIController = require(ReplicatedStorage:WaitForChild("MentuxOS"):WaitForChild("Client"):WaitForChild("GUIController"))

local function log(message)
	print(message)
end

local guiController = GUIController.new({
	fallbackEvents = {
		{ "click", "login_button", true },
		{ "doubleclick", "desktop_icon_1", true },
	},
	fallbackInputText = {
		"ls\n",
		"pwd\n",
		"exit\n",
	},
})

local ok, result = pcall(function()
	return Main.boot({
		logger = log,
		trace = false,
		memorySize = 8192,
		guiController = guiController,
	})
end)

if not ok then
	warn("[MentuxOS] Boot failed: " .. tostring(result))
elseif not result.result.ok then
	warn("[MentuxOS] Kernel crashed: " .. tostring(result.result.error))
end
