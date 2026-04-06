local Util = require(script.Parent:WaitForChild("Util"))

local VFS = {}
VFS.__index = VFS

local function makeDirectory(children)
	return {
		kind = "dir",
		children = children or {},
	}
end

local function normalizeNode(node)
	if node == nil then
		return makeDirectory()
	end

	if type(node) ~= "table" then
		return {
			kind = "file",
			content = node,
			metadata = {},
		}
	end

	if node.kind == "dir" then
		local children = {}
		for name, child in pairs(node.children or {}) do
			children[name] = normalizeNode(child)
		end

		return makeDirectory(children)
	end

	if node.kind == "file" then
		return {
			kind = "file",
			content = Util.deepCopy(node.content),
			metadata = Util.deepCopy(node.metadata or {}),
		}
	end

	error("Unknown VFS node kind " .. tostring(node.kind))
end

local function splitPath(path)
	assert(type(path) == "string" and path:sub(1, 1) == "/", "VFS paths must be absolute")
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		table.insert(parts, part)
	end
	return parts
end

function VFS.new(rootNode)
	local self = setmetatable({}, VFS)
	self.root = normalizeNode(rootNode)
	return self
end

function VFS:_walk(path, createMissing)
	if path == "/" then
		return self.root, nil, nil
	end

	local current = self.root
	local parts = splitPath(path)

	for index, part in ipairs(parts) do
		assert(current.kind == "dir", "Attempted to traverse through a file at " .. path)

		local child = current.children[part]
		if not child then
			if createMissing then
				child = makeDirectory()
				current.children[part] = child
			else
				return nil, current, part
			end
		end

		if index == #parts then
			return child, current, part
		end

		current = child
	end

	return current, nil, nil
end

function VFS:ensureDirectory(path)
	if path == "/" then
		return self.root
	end

	local node = self.root
	for _, part in ipairs(splitPath(path)) do
		assert(node.kind == "dir", "Cannot create a directory under a file node")
		node.children[part] = node.children[part] or makeDirectory()
		node = node.children[part]
		assert(node.kind == "dir", "Path component already exists as a file: " .. path)
	end

	return node
end

function VFS:exists(path)
	local node = self:_walk(path, false)
	return node ~= nil
end

function VFS:readFile(path)
	local node = self:_walk(path, false)
	assert(node and node.kind == "file", "No file at " .. path)
	return Util.deepCopy(node.content)
end

function VFS:writeFile(path, content)
	local parts = splitPath(path)
	local filename = table.remove(parts)
	local directoryPath = #parts > 0 and ("/" .. table.concat(parts, "/")) or "/"
	local directoryNode = self:ensureDirectory(directoryPath)

	directoryNode.children[filename] = {
		kind = "file",
		content = Util.deepCopy(content),
		metadata = {
			size = type(content) == "string" and #content or nil,
		},
	}
end

function VFS:appendFile(path, content)
	local existing = ""
	if self:exists(path) then
		local node = self:_walk(path, false)
		assert(node and node.kind == "file", "Cannot append to a directory at " .. path)
		assert(type(node.content) == "string", "Can only append to text files at " .. path)
		existing = node.content
	end

	self:writeFile(path, tostring(existing) .. tostring(content))
end

function VFS:deletePath(path)
	assert(path ~= "/", "Cannot delete the filesystem root")
	local _, parent, leafName = self:_walk(path, false)
	assert(parent and leafName, "No path at " .. path)
	parent.children[leafName] = nil
	return true
end

function VFS:movePath(sourcePath, destinationPath)
	assert(sourcePath ~= "/", "Cannot move the filesystem root")
	local node, sourceParent, sourceName = self:_walk(sourcePath, false)
	assert(node and sourceParent and sourceName, "No path at " .. sourcePath)

	local destinationParts = splitPath(destinationPath)
	local destinationName = table.remove(destinationParts)
	local destinationDirectoryPath = #destinationParts > 0 and ("/" .. table.concat(destinationParts, "/")) or "/"
	local destinationDirectory = self:ensureDirectory(destinationDirectoryPath)

	destinationDirectory.children[destinationName] = node
	sourceParent.children[sourceName] = nil
	return true
end

function VFS:listDir(path)
	local node = self:_walk(path, false)
	assert(node and node.kind == "dir", "No directory at " .. path)

	local entries = {}
	for name in pairs(node.children) do
		table.insert(entries, name)
	end
	table.sort(entries)
	return entries
end

function VFS:stat(path)
	local node = self:_walk(path, false)
	if not node then
		return nil
	end

	if node.kind == "dir" then
		local entries = self:listDir(path)
		return {
			kind = "dir",
			childCount = #entries,
		}
	end

	local metadata = Util.deepCopy(node.metadata or {})
	metadata.kind = "file"
	return metadata
end

return VFS
