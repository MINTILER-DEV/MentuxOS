return {
	parse = [[
if argc() == 0 {
	libReturn(false);
}

libReturn(jsonParse(argv(1)));
]],
	stringify = [[
if argc() == 0 {
	libReturn(false);
}

libReturn(jsonStringify(argv(1)));
]],
}
