local GrammarSpec = require(script.Parent:WaitForChild("GrammarSpec"))

local Tokenizer = {}

local KEYWORDS = {}
for _, keyword in ipairs(GrammarSpec.keywords) do
	KEYWORDS[keyword] = true
end

local TWO_CHAR_SYMBOLS = {
	["=="] = true,
	["!="] = true,
	["<="] = true,
	[">="] = true,
	["=>"] = true,
	["&&"] = true,
	["||"] = true,
	["++"] = true,
	["--"] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["::"] = true,
}

local function isIdentifierStart(character)
	return character:match("[%a_]")
end

local function isIdentifierPart(character)
	return character:match("[%w_]")
end

local function token(kind, value, lexeme, line, column)
	return {
		kind = kind,
		value = value,
		lexeme = lexeme,
		line = line,
		column = column,
	}
end

function Tokenizer.tokenize(source)
	assert(type(source) == "string", "Tokenizer.tokenize expects source text")

	local tokens = {}
	local index = 1
	local line = 1
	local column = 1

	local function peek(offset)
		offset = offset or 0
		return source:sub(index + offset, index + offset)
	end

	local function advance()
		local character = peek()
		index += 1
		if character == "\n" then
			line += 1
			column = 1
		else
			column += 1
		end
		return character
	end

	local function add(kind, value, lexeme, startLine, startColumn)
		table.insert(tokens, token(kind, value, lexeme, startLine, startColumn))
	end

	while index <= #source do
		local character = peek()

		if character == "" then
			break
		elseif character:match("%s") then
			advance()
		elseif character == "/" and peek(1) == "/" then
			while index <= #source and peek() ~= "\n" do
				advance()
			end
		elseif character == "/" and peek(1) == "*" then
			local startLine = line
			local startColumn = column
			advance()
			advance()
			while index <= #source do
				if peek() == "*" and peek(1) == "/" then
					advance()
					advance()
					break
				end
				advance()
			end
			assert(not (peek() == "" and source:sub(index - 2, index - 1) ~= "*/"), string.format("Unterminated block comment at %d:%d", startLine, startColumn))
		elseif character == "$" and peek(1) == '"' then
			local startIndex = index
			local startLine = line
			local startColumn = column
			advance()
			advance()
			local parts = {}
			while index <= #source and peek() ~= '"' do
				local nextCharacter = advance()
				if nextCharacter == "\\" then
					local escaped = advance()
					if escaped == "n" then
						table.insert(parts, "\n")
					elseif escaped == "t" then
						table.insert(parts, "\t")
					else
						table.insert(parts, escaped)
					end
				else
					table.insert(parts, nextCharacter)
				end
			end
			assert(peek() == '"', string.format("Unterminated interpolated string at %d:%d", startLine, startColumn))
			advance()
			add("interpolated_string", table.concat(parts), source:sub(startIndex, index - 1), startLine, startColumn)
		elseif character == '"' then
			local startIndex = index
			local startLine = line
			local startColumn = column
			advance()
			local parts = {}
			while index <= #source and peek() ~= '"' do
				local nextCharacter = advance()
				if nextCharacter == "\\" then
					local escaped = advance()
					if escaped == "n" then
						table.insert(parts, "\n")
					elseif escaped == "t" then
						table.insert(parts, "\t")
					else
						table.insert(parts, escaped)
					end
				else
					table.insert(parts, nextCharacter)
				end
			end
			assert(peek() == '"', string.format("Unterminated string literal at %d:%d", startLine, startColumn))
			advance()
			add("string", table.concat(parts), source:sub(startIndex, index - 1), startLine, startColumn)
		elseif isIdentifierStart(character) then
			local startIndex = index
			local startLine = line
			local startColumn = column
			repeat
				advance()
			until not isIdentifierPart(peek())
			local lexeme = source:sub(startIndex, index - 1)
			if KEYWORDS[lexeme] then
				add("keyword", lexeme, lexeme, startLine, startColumn)
			else
				add("identifier", lexeme, lexeme, startLine, startColumn)
			end
		elseif character:match("%d") then
			local startIndex = index
			local startLine = line
			local startColumn = column
			repeat
				advance()
			until not peek():match("[%d_]")
			if peek() == "." and peek(1):match("%d") then
				advance()
				repeat
					advance()
				until not peek():match("[%d_]")
			end
			local lexeme = source:sub(startIndex, index - 1):gsub("_", "")
			add("number", tonumber(lexeme), lexeme, startLine, startColumn)
		else
			local startLine = line
			local startColumn = column
			local twoCharacter = character .. peek(1)
			if TWO_CHAR_SYMBOLS[twoCharacter] then
				advance()
				advance()
				add("symbol", twoCharacter, twoCharacter, startLine, startColumn)
			else
				advance()
				add("symbol", character, character, startLine, startColumn)
			end
		end
	end

	table.insert(tokens, token("eof", "<eof>", "<eof>", line, column))
	return tokens
end

return Tokenizer
