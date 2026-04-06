local Util = {}

local function isIdentifier(value)
	return type(value) == "string" and value:match("^[%a_][%w_]*$")
end

function Util.deepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local clone = {}
	seen[value] = clone

	for key, nestedValue in pairs(value) do
		clone[Util.deepCopy(key, seen)] = Util.deepCopy(nestedValue, seen)
	end

	return clone
end

function Util.trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.split(text, delimiter)
	local parts = {}
	local pattern = string.format("([^%s]+)", delimiter)

	for part in string.gmatch(text, pattern) do
		table.insert(parts, part)
	end

	return parts
end

function Util.stringify(value, depth, seen)
	depth = depth or 0
	seen = seen or {}

	if type(value) ~= "table" then
		if type(value) == "string" then
			return value
		end

		return tostring(value)
	end

	if seen[value] then
		return "<cycle>"
	end

	seen[value] = true

	local arrayLength = #value
	local parts = {}

	if arrayLength > 0 then
		for index = 1, arrayLength do
			table.insert(parts, Util.stringify(value[index], depth + 1, seen))
		end

		return "[" .. table.concat(parts, ", ") .. "]"
	end

	for key, nestedValue in pairs(value) do
		local renderedKey = if isIdentifier(key) then key else ("[" .. tostring(key) .. "]")
		table.insert(parts, renderedKey .. "=" .. Util.stringify(nestedValue, depth + 1, seen))
	end

	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

return Util
