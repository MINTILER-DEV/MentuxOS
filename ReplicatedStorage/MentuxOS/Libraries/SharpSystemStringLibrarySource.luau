return {
	["String.charAt"] = [[
let args = listNew();
if argc() >= 1 {
	push(args, argv(1));
}
if argc() >= 2 {
	push(args, argv(2));
}
let result = libCall("/lib/core/string.mxl", "charAt", args);
libReturn(result);
]],
	["String.concat"] = [[
let args = listNew();
if argc() >= 1 {
	push(args, argv(1));
}
if argc() >= 2 {
	push(args, argv(2));
}
let result = libCall("/lib/core/string.mxl", "concat", args);
libReturn(result);
]],
	["String.substr"] = [[
let args = listNew();
if argc() >= 1 {
	push(args, argv(1));
}
if argc() >= 2 {
	push(args, argv(2));
}
if argc() >= 3 {
	push(args, argv(3));
}
let result = libCall("/lib/core/string.mxl", "substr", args);
libReturn(result);
]],
	["String.split"] = [[
let args = listNew();
if argc() >= 1 {
	push(args, argv(1));
}
if argc() >= 2 {
	push(args, argv(2));
}
let result = libCall("/lib/core/string.mxl", "split", args);
libReturn(result);
]],
}
