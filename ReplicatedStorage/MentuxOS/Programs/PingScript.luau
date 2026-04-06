return [[
let outputId = envGet("TERM_OUTPUT");

if argc() == 0 {
	guiAppend(outputId, "usage: ping <url>");
	exit(1);
}

let url = argv(1);
let headers = listNew();
let response = httpRequest(url, "GET", headers, "");
let ok = get(response, 1);
let statusCode = get(response, 2);
let statusMessage = get(response, 3);
let elapsedMs = get(response, 5);

if ok == true {
	guiAppend(outputId, concat("Reply from ", url));
	guiAppend(outputId, concat("Status: ", concat(statusCode, concat(" ", statusMessage))));
	guiAppend(outputId, concat("Time: ", concat(elapsedMs, "ms")));
	exit(0);
}

guiAppend(outputId, concat("Ping failed for ", url));
guiAppend(outputId, concat("Status: ", concat(statusCode, concat(" ", statusMessage))));
guiAppend(outputId, concat("Time: ", concat(elapsedMs, "ms")));
exit(1);
]]
