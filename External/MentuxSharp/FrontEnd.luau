local Tokenizer = require(script.Parent:WaitForChild("Tokenizer"))
local Parser = require(script.Parent:WaitForChild("Parser"))

local FrontEnd = {}

function FrontEnd.tokenize(source)
	return Tokenizer.tokenize(source)
end

function FrontEnd.parse(source)
	return Parser.parse(source)
end

function FrontEnd.parseDetailed(source)
	local tokens = Tokenizer.tokenize(source)
	local ast = Parser.parseTokens(tokens)
	return {
		tokens = tokens,
		ast = ast,
	}
end

function FrontEnd.tryParse(source)
	local ok, result = pcall(function()
		return FrontEnd.parseDetailed(source)
	end)

	if ok then
		return {
			ok = true,
			tokens = result.tokens,
			ast = result.ast,
		}
	end

	return {
		ok = false,
		error = result,
	}
end

return FrontEnd
