return {
	["Json.parse"] = [[
if argc() == 0 {
	libReturn(false);
}

libReturn(jsonParse(argv(1)));
]],
	["Json.stringify"] = [[
if argc() == 0 {
	libReturn(false);
}

libReturn(jsonStringify(argv(1)));
]],
}
