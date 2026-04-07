return [[
envSet("DEFAULT_USER", "tester");
envSet("DEFAULT_PASSWORD", "123456");
envSet("PATH", concat(concat("/user/", envGet("DEFAULT_USER")), "/apps:/apps/system:/bin:/boot"));

if exists("/user/tester/password.txt") == false {
	writeFile("/user/tester/password.txt", "123456");
	writeFile("/user/tester/profile.txt", "Mentux test user");
	writeFile("/user/tester/welcome.txt", "Welcome to your Mentux home directory.");
}

if exists("/user/tester/username.txt") == false {
	writeFile("/user/tester/username.txt", "tester");
}

if exists("/user/tester/settings/theme.txt") == false {
	writeFile("/user/tester/settings/theme.txt", "dark");
}

if exists("/user/tester/settings/animations.txt") == false {
	writeFile("/user/tester/settings/animations.txt", "on");
}

if exists("/user/tester/settings/display.txt") == false {
	writeFile("/user/tester/settings/display.txt", "100");
}

if exists("/user/tester/apps/readme.txt") == false {
	writeFile("/user/tester/apps/readme.txt", "Install per-user apps in /user/tester/apps/<appid>/main.mtx");
}

if exists("/user/tester/desktop/terminal.sym") == false {
	writeFile("/user/tester/desktop/terminal.sym", "terminal|Terminal|0.06|0.24");
}

if exists("/user/tester/desktop/files.sym") == false {
	writeFile("/user/tester/desktop/files.sym", "files|Files|0.18|0.24");
}

if exists("/user/tester/desktop/browser.sym") == false {
	writeFile("/user/tester/desktop/browser.sym", "browser|Browser|0.30|0.24");
}

if exists("/user/tester/desktop/code.sym") == false {
	writeFile("/user/tester/desktop/code.sym", "code|Code|0.42|0.24");
}

if exists("/user/tester/desktop/settings.sym") == false {
	writeFile("/user/tester/desktop/settings.sym", "settings|Settings|0.54|0.24");
}

let appArgs = listNew();
exec("mtxdthost", appArgs);
exec("gui", appArgs);
exit(0);
]]
