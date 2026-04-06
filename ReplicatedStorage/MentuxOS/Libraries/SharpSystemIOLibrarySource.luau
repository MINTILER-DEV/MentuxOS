return {
	["File.read"] = [[
if argc() == 0 {
	libReturn(false);
}

libReturn(readFile(resolvePath(argv(1))));
]],
	["File.write"] = [[
if argc() < 2 {
	libReturn(false);
}

libReturn(writeFile(resolvePath(argv(1)), argv(2)));
]],
	["File.append"] = [[
if argc() < 2 {
	libReturn(false);
}

libReturn(appendFile(resolvePath(argv(1)), argv(2)));
]],
	["File.exists"] = [[
if argc() == 0 {
	libReturn(false);
}

libReturn(exists(resolvePath(argv(1))));
]],
	["File.statKind"] = [[
if argc() == 0 {
	libReturn("missing");
}

libReturn(statKind(resolvePath(argv(1))));
]],
	["Directory.list"] = [[
if argc() == 0 {
	libReturn(listDir(resolvePath(".")));
}

libReturn(listDir(resolvePath(argv(1))));
]],
	["Path.resolve"] = [[
if argc() == 0 {
	libReturn(resolvePath("."));
}

libReturn(resolvePath(argv(1)));
]],
}
