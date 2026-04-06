local ExecutableFormat = require(script.Parent:WaitForChild("ExecutableFormat"))
local KernelRuntime = require(script.Parent:WaitForChild("KernelRuntime"))
local VFS = require(script.Parent:WaitForChild("VFS"))

local Bootloader = {}
Bootloader.__index = Bootloader

function Bootloader.new(options)
	local self = setmetatable({}, Bootloader)
	self.trace = options and options.trace == true or false
	self.memorySize = options and options.memorySize or 8192
	self.defaultMaxCycles = options and options.defaultMaxCycles or 10000000
	self.guiController = options and options.guiController or nil
	self.logger = options and options.logger or function(message)
		print(message)
	end
	return self
end

function Bootloader:_log(message)
	self.logger("[MentuxOS] " .. message)
end

function Bootloader:boot(diskImage)
	self:_log("Power on")

	local vfs = VFS.new(diskImage)
	local runtime = KernelRuntime.new({
		vfs = vfs,
		trace = self.trace,
		memorySize = self.memorySize,
		defaultMaxCycles = self.defaultMaxCycles,
		logger = self.logger,
		guiController = self.guiController,
	})

	self:_log("Mounted virtual filesystem")
	assert(vfs:exists("/boot/kernel.mtx"), "Kernel executable not found at /boot/kernel.mtx")

	local kernelImage = vfs:readFile("/boot/kernel.mtx")
	ExecutableFormat.validate(kernelImage)
	self:_log("Loaded /boot/kernel.mtx")
	self:_log("Transferring control to kernel entry point")

	local result = runtime:runImage(kernelImage, {
		path = "/boot/kernel.mtx",
		argv = { "boot" },
		maxCycles = self.defaultMaxCycles,
	})

	self:_log(string.format("Kernel stopped with exit code %d", result.exitCode))
	return {
		vfs = vfs,
		runtime = runtime,
		result = result,
	}
end

return Bootloader
