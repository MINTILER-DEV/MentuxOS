local Util = require(script.Parent:WaitForChild("Util"))

local LibraryFormat = {}

LibraryFormat.MAGIC = "MENTUX_LIB"
LibraryFormat.VERSION = 1

function LibraryFormat.validate(library)
	assert(type(library) == "table", "Library image must be a table")
	assert(library.magic == LibraryFormat.MAGIC, "Invalid Mentux library magic")
	assert(library.version == LibraryFormat.VERSION, "Unsupported Mentux library version")
	assert(type(library.name) == "string" and library.name ~= "", "Library name is required")
	assert(type(library.exports) == "table", "Library exports section is required")
	for exportName, exportValue in pairs(library.exports) do
		assert(type(exportName) == "string" and exportName ~= "", "Library export names must be non-empty strings")
		assert(exportValue ~= nil, "Library export " .. exportName .. " must not be nil")
	end
end

function LibraryFormat.new(spec)
	assert(type(spec) == "table", "Library spec must be a table")

	local library = {
		magic = LibraryFormat.MAGIC,
		version = LibraryFormat.VERSION,
		name = spec.name or "unnamed-library",
		kind = spec.kind or "library",
		exports = Util.deepCopy(spec.exports or {}),
		metadata = Util.deepCopy(spec.metadata or {}),
	}

	LibraryFormat.validate(library)
	return library
end

return LibraryFormat
