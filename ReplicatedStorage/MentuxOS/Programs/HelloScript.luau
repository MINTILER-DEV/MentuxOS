return [[
let outputId = envGet("TERM_OUTPUT");

guiAppend(outputId, "Hello from Mentux userland");
guiAppend(outputId, concat("argv count: ", argc()));

let index = 1;
while index <= argc() {
	guiAppend(outputId, argv(index));
	index = index + 1;
}

exit(0);
]]
