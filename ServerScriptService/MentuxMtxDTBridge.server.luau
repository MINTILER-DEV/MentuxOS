local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mentuxRoot = ReplicatedStorage:WaitForChild("MentuxOS")

local runtimeFolder = mentuxRoot:FindFirstChild("Runtime")
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "Runtime"
	runtimeFolder.Parent = mentuxRoot
end

local bridge = runtimeFolder:FindFirstChild("MtxDTBridge")
if not bridge then
	bridge = Instance.new("RemoteFunction")
	bridge.Name = "MtxDTBridge"
	bridge.Parent = runtimeFolder
end

local dnsStore = nil
local serviceStore = nil
local kvStore = nil

pcall(function()
	dnsStore = DataStoreService:GetDataStore("Mentux_MtxDT_DNS_v1")
	serviceStore = DataStoreService:GetDataStore("Mentux_MtxDT_Services_v1")
	kvStore = DataStoreService:GetDataStore("Mentux_MtxDT_KV_v1")
end)

local memoryState = {
	dns = {},
	services = {},
	kv = {},
}

local liveState = {
	channelSubscriptions = {},
	channelSessions = {},
	sessionQueues = {},
}

local function deepCopy(value, seen)
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
		clone[deepCopy(key, seen)] = deepCopy(nestedValue, seen)
	end
	return clone
end

local function serviceKey(ip, port)
	return tostring(ip or "") .. ":" .. tostring(tonumber(port) or 80)
end

local function kvKey(scope, key)
	return tostring(scope or "global") .. "::" .. tostring(key or "")
end

local function loadFromStore(store, fallbackTable, key)
	if store then
		local ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		if ok and value ~= nil then
			return value
		end
	end
	return deepCopy(fallbackTable[key])
end

local function saveToStore(store, fallbackTable, key, value)
	fallbackTable[key] = deepCopy(value)
	if store then
		pcall(function()
			store:SetAsync(key, value)
		end)
	end
end

local function normalizeRoutePath(path)
	local value = tostring(path or "/")
	if value == "" then
		return "/"
	end
	if value:sub(1, 1) ~= "/" then
		value = "/" .. value
	end
	if #value > 1 and value:sub(-1) == "/" then
		value = value:sub(1, -2)
	end
	return value
end

local function parseUrl(url)
	local raw = tostring(url or "")
	local protocol, remainder = raw:match("^(%a[%w+.-]*)://(.+)$")
	if not protocol then
		protocol = "mtx"
		remainder = raw
	end

	local hostPort, path = remainder:match("^([^/]+)(/.*)$")
	if not hostPort then
		hostPort = remainder
		path = "/"
	end

	local host, portText = hostPort:match("^([^:]+):?(%d*)$")
	return {
		protocol = protocol,
		host = tostring(host or ""),
		port = tonumber(portText) or 80,
		path = normalizeRoutePath(path),
		url = raw,
	}
end

local function makeSessionKey(player, request)
	local userId = 0
	pcall(function()
		userId = tonumber(player.UserId) or 0
	end)
	local session = tostring((request or {}).session or "default")
	return tostring(userId) .. ":" .. session
end

local function ensureQueue(sessionKey)
	local queue = liveState.sessionQueues[sessionKey]
	if not queue then
		queue = {}
		liveState.sessionQueues[sessionKey] = queue
	end
	return queue
end

local function pushSessionMessage(sessionKey, payload)
	local queue = ensureQueue(sessionKey)
	table.insert(queue, deepCopy(payload))
	while #queue > 64 do
		table.remove(queue, 1)
	end
end

local function fanoutChannelMessage(channel, payload)
	local sessions = liveState.channelSessions[channel]
	if not sessions then
		return
	end
	for sessionKey in pairs(sessions) do
		pushSessionMessage(sessionKey, payload)
	end
end

local function ensureChannelSubscription(channel)
	if liveState.channelSubscriptions[channel] then
		return
	end

	local ok, subscription = pcall(function()
		return MessagingService:SubscribeAsync(channel, function(message)
			local payload = {
				channel = channel,
				message = if type(message.Data) == "table" then deepCopy(message.Data.message) else message.Data,
				sender = if type(message.Data) == "table" then tostring(message.Data.sender or "") else "",
				sentAt = if type(message.Data) == "table" and message.Data.sentAt then tonumber(message.Data.sentAt) or os.time() else os.time(),
			}
			fanoutChannelMessage(channel, payload)
		end)
	end)

	if ok then
		liveState.channelSubscriptions[channel] = subscription
	else
		warn("[MentuxOS] MtxDT MessagingService subscribe failed for " .. channel .. ": " .. tostring(subscription))
		liveState.channelSubscriptions[channel] = false
	end
end

local function resolveHost(hostname, port)
	local dnsRecord = loadFromStore(dnsStore, memoryState.dns, tostring(hostname))
	if type(dnsRecord) ~= "table" then
		return nil, nil
	end

	local ip = dnsRecord.ip
	local resolvedPort = tonumber(port) or tonumber(dnsRecord.defaultPort) or 80
	local serviceRecord = loadFromStore(serviceStore, memoryState.services, serviceKey(ip, resolvedPort))
	if type(serviceRecord) ~= "table" then
		return dnsRecord, nil
	end

	return dnsRecord, serviceRecord
end

local function findRoute(site, path)
	local normalizedPath = normalizeRoutePath(path)
	for _, route in ipairs(site.routes or {}) do
		if normalizeRoutePath(route.path) == normalizedPath then
			return route
		end
	end
	if normalizedPath == "/" then
		for _, route in ipairs(site.routes or {}) do
			if normalizeRoutePath(route.path) == "/index" then
				return route
			end
		end
	end
	return nil
end

bridge.OnServerInvoke = function(player, request)
	request = request or {}
	local op = tostring(request.op or "")

	if op == "registerSite" then
		local site = request.site
		if type(site) ~= "table" then
			return {
				ok = false,
				error = "Missing site payload",
			}
		end

		local host = tostring(site.host or "")
		local ip = tostring(site.ip or "")
		local port = tonumber(site.port) or 80
		if host == "" or ip == "" then
			return {
				ok = false,
				error = "Site host or IP missing",
			}
		end

		local siteCopy = deepCopy(site)
		siteCopy.port = port
		siteCopy.host = host
		siteCopy.ip = ip
		siteCopy.routes = type(siteCopy.routes) == "table" and siteCopy.routes or {}

		saveToStore(dnsStore, memoryState.dns, host, {
			host = host,
			ip = ip,
			defaultPort = port,
			updatedAt = os.time(),
		})
		saveToStore(serviceStore, memoryState.services, serviceKey(ip, port), siteCopy)

		return {
			ok = true,
			host = host,
			ip = ip,
			port = port,
			routes = #(siteCopy.routes or {}),
		}
	end

	if op == "resolveHost" then
		local host = tostring(request.host or "")
		local port = tonumber(request.port) or 80
		local dnsRecord, serviceRecord = resolveHost(host, port)
		if not dnsRecord or not serviceRecord then
			return {
				ok = false,
				error = "Host not found",
			}
		end

		return {
			ok = true,
			host = host,
			ip = tostring(dnsRecord.ip or ""),
			port = tonumber(serviceRecord.port) or port,
			rootPath = tostring(serviceRecord.rootPath or ""),
			siteTitle = tostring(serviceRecord.title or serviceRecord.host or host),
		}
	end

	if op == "request" then
		local parsed = parseUrl(request.url)
		local dnsRecord, serviceRecord = resolveHost(parsed.host, parsed.port)
		if not dnsRecord or not serviceRecord then
			return {
				ok = false,
				status = 404,
				error = "Host not found",
				response = {
					status = 404,
					page = {
						title = "Not Found",
						blocks = {
							{ kind = "heading", text = "Host not found" },
							{ kind = "text", text = "No MtxDT host is registered for this address." },
						},
					},
				},
			}
		end

		local route = findRoute(serviceRecord, parsed.path)
		if not route then
			return {
				ok = false,
				status = 404,
				error = "Route not found",
				response = {
					status = 404,
					page = {
						title = "Not Found",
						blocks = {
							{ kind = "heading", text = "Route not found" },
							{ kind = "text", text = parsed.path .. " is not registered on this site." },
						},
					},
				},
			}
		end

		if route.kind == "dynamic" then
			return {
				ok = true,
				status = 200,
				kind = "dynamic",
				handlerPath = tostring(route.handlerPath or ""),
				handlerExport = tostring(route.handlerExport or ""),
				request = {
					url = parsed.url,
					host = parsed.host,
					port = parsed.port,
					path = parsed.path,
					method = tostring(request.method or "GET"),
					body = request.body,
					headers = deepCopy(request.headers or {}),
					ip = tostring(dnsRecord.ip or ""),
					rootPath = tostring(serviceRecord.rootPath or ""),
				},
			}
		end

		return {
			ok = true,
			status = tonumber(route.status) or 200,
			kind = "static",
			response = deepCopy(route.response),
		}
	end

	if op == "storeGet" then
		local key = kvKey(request.scope, request.key)
		return {
			ok = true,
			value = loadFromStore(kvStore, memoryState.kv, key),
		}
	end

	if op == "storeSet" then
		local key = kvKey(request.scope, request.key)
		saveToStore(kvStore, memoryState.kv, key, request.value)
		return {
			ok = true,
		}
	end

	if op == "socketSubscribe" then
		local channel = tostring(request.channel or "")
		if channel == "" then
			return {
				ok = false,
				error = "Missing channel",
			}
		end

		local sessionKey = makeSessionKey(player, request)
		liveState.channelSessions[channel] = liveState.channelSessions[channel] or {}
		liveState.channelSessions[channel][sessionKey] = true
		ensureQueue(sessionKey)
		ensureChannelSubscription(channel)
		return {
			ok = true,
			channel = channel,
		}
	end

	if op == "socketPublish" then
		local channel = tostring(request.channel or "")
		if channel == "" then
			return {
				ok = false,
				error = "Missing channel",
			}
		end

		local payload = {
			channel = channel,
			message = request.message,
			sender = tostring(request.sender or "guest"),
			sentAt = os.time(),
		}

		local ok, publishResult = pcall(function()
			MessagingService:PublishAsync(channel, payload)
		end)
		if not ok then
			warn("[MentuxOS] MtxDT MessagingService publish failed for " .. channel .. ": " .. tostring(publishResult))
		end

		fanoutChannelMessage(channel, payload)
		return {
			ok = true,
		}
	end

	if op == "socketPoll" then
		local sessionKey = makeSessionKey(player, request)
		local queue = ensureQueue(sessionKey)
		if #queue == 0 then
			return {
				ok = true,
				message = false,
			}
		end

		return {
			ok = true,
			message = table.remove(queue, 1),
		}
	end

	return {
		ok = false,
		error = "Unknown MtxDT bridge operation: " .. op,
	}
end
