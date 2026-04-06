local Bootloader = require(script.Parent:WaitForChild("Bootloader"))
local ExamplePrograms = require(script.Parent:WaitForChild("ExamplePrograms"))

local Main = {}

function Main.boot(options)
	local bootloader = Bootloader.new(options or {})
	return bootloader:boot(ExamplePrograms.createSystemDisk())
end

return Main
