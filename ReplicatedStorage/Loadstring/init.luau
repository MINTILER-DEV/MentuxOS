local compile = require(script:WaitForChild("Yueliang"))
local createExecutable = require(script:WaitForChild("FiOne"))
getfenv().script = nil

return function(source, env)
	local executable
	local env = env or getfenv(2)
	local name = (env.script and env.script:GetFullName())
	local ran, failureReason = pcall(function()
		local compiledBytecode = compile(source, name) -- this should be the os's executable file format
		executable = createExecutable(compiledBytecode, env)
	end)
	
	if ran then
		return setfenv(executable, env)
	end
	return nil, failureReason
end