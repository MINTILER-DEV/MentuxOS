local Syscalls = {}
Syscalls.__index = Syscalls

function Syscalls.new()
	local self = setmetatable({}, Syscalls)
	self.handlers = {}
	return self
end

function Syscalls:register(name, handler)
	assert(type(name) == "string" and name ~= "", "Syscall name is required")
	assert(type(handler) == "function", "Syscall handler must be a function")
	self.handlers[name] = handler
end

function Syscalls:invoke(name, runtime, process, args)
	local handler = self.handlers[name]
	assert(handler, "Unknown syscall " .. tostring(name))
	return handler(runtime, process, args)
end

return Syscalls
