local Util = require(script.Parent:WaitForChild("Util"))

local ExecutableFormat = {}

ExecutableFormat.MAGIC = "MENTUX_EXEC"
ExecutableFormat.VERSION = 1

local function normalizeDataSection(data)
	local normalized = {}

	for index, entry in ipairs(data or {}) do
		if type(entry) == "table" and entry.offset ~= nil then
			normalized[index] = {
				offset = entry.offset,
				value = Util.deepCopy(entry.value),
			}
		else
			normalized[index] = {
				offset = index - 1,
				value = Util.deepCopy(entry),
			}
		end
	end

	return normalized
end

function ExecutableFormat.validate(executable)
	assert(type(executable) == "table", "Executable image must be a table")
	assert(executable.magic == ExecutableFormat.MAGIC, "Invalid Mentux executable magic")
	assert(executable.version == ExecutableFormat.VERSION, "Unsupported Mentux executable version")
	assert(type(executable.name) == "string" and executable.name ~= "", "Executable name is required")
	assert(type(executable.code) == "table", "Executable code section is required")
	assert(type(executable.entryPoint) == "number", "Executable entryPoint must be numeric")
end

function ExecutableFormat.new(spec)
	assert(type(spec) == "table", "Executable spec must be a table")

	local executable = {
		magic = ExecutableFormat.MAGIC,
		version = ExecutableFormat.VERSION,
		name = spec.name or "unnamed",
		kind = spec.kind or "program",
		entryPoint = spec.entryPoint or 0,
		stackSize = spec.stackSize or 128,
		code = Util.deepCopy(spec.code or {}),
		constants = Util.deepCopy(spec.constants or {}),
		data = normalizeDataSection(spec.data),
		metadata = Util.deepCopy(spec.metadata or {}),
	}

	ExecutableFormat.validate(executable)
	return executable
end

return ExecutableFormat
