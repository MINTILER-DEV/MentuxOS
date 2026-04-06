return [[
let outputId = envGet("TERM_OUTPUT");

if argc() == 0 {
	guiAppend(outputId, "usage: curl <url> [Header:Value]...");
	exit(1);
}

let url = argv(1);
let headers = listNew();
let index = 2;
while index <= argc() {
	push(headers, argv(index));
	index = index + 1;
}

let response = httpRequest(url, "GET", headers, "");
let ok = get(response, 1);
let statusCode = get(response, 2);
let statusMessage = get(response, 3);
let body = get(response, 4);
let elapsedMs = get(response, 5);
let responseHeaders = get(response, 7);

guiAppend(outputId, concat("URL: ", url));
guiAppend(outputId, concat("Status: ", concat(statusCode, concat(" ", statusMessage))));
guiAppend(outputId, concat("Time: ", concat(elapsedMs, "ms")));

if len(responseHeaders) > 0 {
	guiAppend(outputId, "Headers:");
	guiAppend(outputId, responseHeaders);
}

if len(body) > 0 {
	guiAppend(outputId, "Body:");
	guiAppend(outputId, body);
}

if ok == true {
	exit(0);
}

exit(1);
]]
