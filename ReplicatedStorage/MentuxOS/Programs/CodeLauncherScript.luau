return [[
let ctorArgs = listNew();
if argc() > 0 {
	push(ctorArgs, argv(1));
} else {
	push(ctorArgs, concat(envGet("HOME"), "/untitled.msh"));
}

let app = libCall("/apps/system/code/main.mxl", "CodeEditorApp.ctor", ctorArgs);
let runArgs = listNew();
push(runArgs, app);
let exitCode = libCall("/apps/system/code/main.mxl", "CodeEditorApp.Run", runArgs);
exit(exitCode);
]]
