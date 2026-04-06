local Memory = {}
Memory.__index = Memory

function Memory.new(size)
	assert(type(size) == "number" and size > 0, "Memory size must be a positive number")

	local self = setmetatable({}, Memory)
	self.size = size
	self.cells = table.create(size)
	return self
end

function Memory:_assertAddress(address)
	assert(type(address) == "number", "Memory address must be numeric")
	assert(address % 1 == 0, "Memory address must be an integer")
	assert(address >= 0 and address < self.size, string.format("Memory address %d out of range 0..%d", address, self.size - 1))
end

function Memory:read(address)
	self:_assertAddress(address)
	return self.cells[address + 1]
end

function Memory:write(address, value)
	self:_assertAddress(address)
	self.cells[address + 1] = value
end

function Memory:bulkWrite(startAddress, values)
	for offset, value in ipairs(values) do
		self:write(startAddress + offset - 1, value)
	end
end

function Memory:reset()
	self.cells = table.create(self.size)
end

return Memory
