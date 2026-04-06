-- server script

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")
local chatConfig = TextChatService:WaitForChild("ChatInputBarConfiguration")

Players.CharacterAutoLoads = false
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable

chatConfig.Enabled = false
chatConfig.KeyboardKeyCode = Enum.KeyCode.Unknown