local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mentuxRoot = ReplicatedStorage:WaitForChild("MentuxOS")

local runtimeFolder = mentuxRoot:FindFirstChild("Runtime")
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "Runtime"
	runtimeFolder.Parent = mentuxRoot
end

local httpBridge = runtimeFolder:FindFirstChild("HttpBridge")
if not httpBridge then
	httpBridge = Instance.new("RemoteFunction")
	httpBridge.Name = "HttpBridge"
	httpBridge.Parent = runtimeFolder
end

local function parseHeaders(rawHeaders)
	local headers = {}
	if type(rawHeaders) ~= "table" then
		return headers
	end

	for _, headerValue in ipairs(rawHeaders) do
		local entry = tostring(headerValue or "")
		local separatorIndex = string.find(entry, ":", 1, true)
		if separatorIndex and separatorIndex > 1 then
			local key = string.sub(entry, 1, separatorIndex - 1)
			local value = string.sub(entry, separatorIndex + 1)
			headers[key] = value:gsub("^%s+", "")
		end
	end

	return headers
end

local function stringifyHeaders(headers)
	local parts = {}
	for key, value in pairs(headers or {}) do
		table.insert(parts, tostring(key) .. ": " .. tostring(value))
	end
	table.sort(parts)
	return table.concat(parts, "\n")
end

httpBridge.OnServerInvoke = function(_, request)
	request = request or {}

	local url = tostring(request.url or "")
	local method = string.upper(tostring(request.method or "GET"))
	local body = request.body
	local headers = parseHeaders(request.headers)

	if url == "" then
		return {
			ok = false,
			statusCode = 0,
			statusMessage = "Missing URL",
			body = "",
			headers = "",
			url = url,
			elapsedMs = 0,
		}
	end

	local startedAt = os.clock()
	local ok, response = pcall(function()
		local requestOptions = {
			Url = url,
			Method = method,
			Headers = headers,
		}

		if body ~= nil and tostring(body) ~= "" and method ~= "GET" and method ~= "HEAD" then
			requestOptions.Body = tostring(body)
		end

		return HttpService:RequestAsync(requestOptions)
	end)
	local elapsedMs = math.floor((os.clock() - startedAt) * 1000)

	if not ok then
		return {
			ok = false,
			statusCode = 0,
			statusMessage = tostring(response),
			body = "",
			headers = "",
			url = url,
			elapsedMs = elapsedMs,
		}
	end

	return {
		ok = response.Success == true,
		statusCode = tonumber(response.StatusCode) or 0,
		statusMessage = tostring(response.StatusMessage or ""),
		body = tostring(response.Body or ""),
		headers = stringifyHeaders(response.Headers),
		url = url,
		elapsedMs = elapsedMs,
	}
end
