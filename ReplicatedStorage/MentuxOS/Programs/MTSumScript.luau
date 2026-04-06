return [[
let outputId = envGet("TERM_OUTPUT");

if argc() == 0 {
	guiAppend(outputId, "usage: mtsum <path> [limit]");
	exit(1);
}

let rawPath = argv(1);
let path = resolvePath(rawPath);
let kind = statKind(path);
let limit = 0;

if argc() > 1 {
	limit = toNumber(argv(2));
}

if kind == "file" {
	if limit > 0 {
		guiAppend(outputId, fileSummary(path, limit));
	} else {
		guiAppend(outputId, fileSummary(path));
	}
} else {
	if kind == "dir" {
		guiAppend(outputId, concat(path, " is a directory"));
	} else {
		guiAppend(outputId, concat(path, " not found"));
	}
}

exit(0);
]]
