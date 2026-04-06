return [[
let app = libCall("/apps/system/settings/main.mxl", "SettingsApp.ctor");
let runArgs = listNew();
push(runArgs, app);
let exitCode = libCall("/apps/system/settings/main.mxl", "SettingsApp.Run", runArgs);
exit(exitCode);
]]
