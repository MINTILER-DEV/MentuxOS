return [[
let jsonLib = "/lib/core/json.mxl";
let styleLib = "/lib/ui/gui.mxl";
let loginAnimated = false;

while true {
	let loginTheme = "dark";
	if exists(concat(concat("/user/", envGet("DEFAULT_USER")), "/settings/theme.txt")) == true {
		loginTheme = readFile(concat(concat("/user/", envGet("DEFAULT_USER")), "/settings/theme.txt"));
	}
	guiReset();
	if loginTheme == "dark" {
		guiBackground("login");
	} else {
		guiBackground("loginLight");
	}
	guiPanel("login_shell", "", 0.5, 0.5, 0.48, 0.56, "panel");
	guiAnchor("login_shell", 0.5, 0.5);
	guiStylePreset("login_shell", styleLib, "login_shell");
	guiPanel("login_badge", "login_shell", 0.08, 0.1, 0.3, 0.1, "accentSoft");
	guiStylePreset("login_badge", styleLib, "login_badge");
	guiLabel("login_badge_label", "login_badge", "Mentux OS", 0.12, 0.23, 0.76, 0.54);
	guiLabel("login_header", "login_shell", "Sign in to your test workspace", 0.08, 0.23, 0.84, 0.1);
	guiLabel("login_copy", "login_shell", "Desktop shortcuts are rendered from /user/<name>/desktop.", 0.08, 0.3, 0.84, 0.08);
	guiLabel("login_user_label", "login_shell", "Username", 0.08, 0.42, 0.3, 0.08);
	guiTextBox("login_username", "login_shell", "username", envGet("DEFAULT_USER"), 0.08, 0.49, 0.84, 0.1, false);
	guiLabel("login_password_label", "login_shell", "Password", 0.08, 0.62, 0.3, 0.08);
	guiTextBox("login_password", "login_shell", "password", envGet("DEFAULT_PASSWORD"), 0.08, 0.69, 0.84, 0.1, true);
	guiLabel("login_status", "login_shell", "Testing account: tester / 123456", 0.08, 0.82, 0.5, 0.08);
	guiButton("login_button", "login_shell", "Log In", 0.68, 0.82, 0.24, 0.1);
	if loginAnimated == false {
		guiTweenPreset("login_shell", "/lib/ui/motion.mxl", "login_shell_intro");
		loginAnimated = true;
	}

	let authenticated = false;
	while authenticated == false {
		let event = guiWait();
		let eventType = get(event, 1);
		let eventId = get(event, 2);

		let tryLogin = false;
		if eventId == "login_button" {
			if eventType == "click" {
				tryLogin = true;
			}
		} else {
			if eventId == "login_password" {
				if eventType == "submit" {
					tryLogin = true;
				}
			}
		}

		if tryLogin == true {
			let username = guiGetText("login_username");
			let password = guiGetText("login_password");
			let passwordPath = concat(concat("/user/", username), "/password.txt");
			if exists(passwordPath) == false {
				guiSetText("login_status", "Unknown user");
			} else {
				if readFile(passwordPath) == password {
					envSet("USER", username);
					envSet("HOME", concat("/user/", username));
					envSet("PWD", concat("/user/", username));
					envSet("PATH", concat(concat("/user/", username), "/apps:/apps/system:/bin:/boot"));
					let settingsDir = concat(concat("/user/", username), "/settings");
					let themePath = concat(settingsDir, "/theme.txt");
					let animationsPath = concat(settingsDir, "/animations.txt");
					let displayPath = concat(settingsDir, "/display.txt");
					let usernamePath = concat(concat("/user/", username), "/username.txt");
					if exists(themePath) == false {
						writeFile(themePath, "dark");
					}
					if exists(animationsPath) == false {
						writeFile(animationsPath, "on");
					}
					if exists(displayPath) == false {
						writeFile(displayPath, "100");
					}
					if exists(usernamePath) == false {
						writeFile(usernamePath, username);
					}
					envSet("THEME", readFile(themePath));
					envSet("ANIMATIONS", readFile(animationsPath));
					envSet("DISPLAY_SIZE", readFile(displayPath));
					envSet("DISPLAY_USERNAME", readFile(usernamePath));
					authenticated = true;
				} else {
					guiSetText("login_status", "Invalid password");
				}
			}
		}
	}

	let onDesktop = true;
	let desktopAnimated = false;
	while onDesktop == true {
		let settingsDir = concat(envGet("HOME"), "/settings");
		let themePath = concat(settingsDir, "/theme.txt");
		let animationsPath = concat(settingsDir, "/animations.txt");
		let displayPath = concat(settingsDir, "/display.txt");
		let usernamePath = concat(envGet("HOME"), "/username.txt");

		if exists(themePath) == true {
			envSet("THEME", readFile(themePath));
		} else {
			envSet("THEME", "dark");
		}

		if exists(animationsPath) == true {
			envSet("ANIMATIONS", readFile(animationsPath));
		} else {
			envSet("ANIMATIONS", "on");
		}

		if exists(displayPath) == true {
			envSet("DISPLAY_SIZE", readFile(displayPath));
		} else {
			envSet("DISPLAY_SIZE", "100");
		}

		if exists(usernamePath) == true {
			envSet("DISPLAY_USERNAME", readFile(usernamePath));
		} else {
			envSet("DISPLAY_USERNAME", envGet("USER"));
		}

		let displayScale = toNumber(envGet("DISPLAY_SIZE"));
		if displayScale <= 0 {
			displayScale = 100;
		}
		displayScale = displayScale / 100;

		guiReset();
		if envGet("THEME") == "dark" {
			guiBackground("desktop");
		} else {
			guiBackground("desktopLight");
		}
		guiPanel("desktop_status", "", 0.02, 0.03, 0.38, 0.09, "accentSoft");
		guiStylePreset("desktop_status", styleLib, "desktop_status");
		guiLabel("desktop_user", "desktop_status", concat("User: ", envGet("DISPLAY_USERNAME")), 0.05, 0.18, 0.42, 0.26);
		guiLabel("desktop_home", "desktop_status", concat("Desktop: ", concat(envGet("HOME"), "/desktop")), 0.05, 0.5, 0.88, 0.24);

		let desktopDir = concat(envGet("HOME"), "/desktop");
		let desktopEntries = listDir(desktopDir);
		let desktopIndex = 1;
		while desktopIndex <= len(desktopEntries) {
			let shortcutName = get(desktopEntries, desktopIndex);
			let shortcutPath = concat(concat(desktopDir, "/"), shortcutName);
			if statKind(shortcutPath) == "file" {
				let shortcutParts = splitText(readFile(shortcutPath), "|");
				let label = get(shortcutParts, 2);
				let posX = toNumber(get(shortcutParts, 3));
				let posY = toNumber(get(shortcutParts, 4));
				let iconId = concat("desktop_icon_", desktopIndex);
				let iconSize = 0.1 * displayScale;
				let iconHeight = iconSize + 0.04;
				let glyph = charAt(label, 1);
				if len(glyph) == 0 {
					glyph = charAt(shortcutName, 1);
				}
				guiButton(iconId, "", "", posX, posY, iconSize, iconHeight);
				guiStylePreset(iconId, styleLib, "desktop_icon_button");
				guiEnableDrag(iconId);
				guiLabel(concat(iconId, "_glyph"), iconId, glyph, 0.18, 0.08, 0.64, 0.44);
				guiStylePreset(concat(iconId, "_glyph"), styleLib, "desktop_icon_glyph");
				guiLabel(concat(iconId, "_label"), iconId, label, 0.08, 0.58, 0.84, 0.28);
				guiStylePreset(concat(iconId, "_label"), styleLib, "desktop_icon_label");
			}
			desktopIndex = desktopIndex + 1;
		}

		guiPanel("desktop_taskbar", "", 0, 0.9, 1, 0.1, "panelDark");
		guiCorner("desktop_taskbar", 0);
		guiStylePreset("desktop_taskbar", styleLib, "taskbar");
		guiPanel("desktop_task_apps", "desktop_taskbar", 0.015, 0.14, 0.72, 0.72, "panelDark");
		guiCorner("desktop_task_apps", 0);
		guiStylePreset("desktop_task_apps", styleLib, "task_strip");
		guiPadding("desktop_task_apps", 0.008, 0.08, 0.008, 0.08);
		guiListLayout("desktop_task_apps", "horizontal", 0.01, "left", "center");
		guiPanel("desktop_task_meta", "desktop_taskbar", 0.76, 0.14, 0.13, 0.72, "accentSoft");
		guiCorner("desktop_task_meta", 0);
		guiStylePreset("desktop_task_meta", styleLib, "task_meta");
		guiLabel("desktop_task_path", "desktop_task_meta", envGet("PWD"), 0.06, 0.18, 0.88, 0.42);
		guiButton("desktop_logout", "desktop_taskbar", "Log Out", 0.91, 0.14, 0.075, 0.72);
		guiCorner("desktop_logout", 0);
		guiStylePreset("desktop_logout", styleLib, "task_logout");

		let taskbarAppIds = listNew();
		let taskbarIndex = 1;
		let systemApps = listDir("/apps/system");
		let systemIndex = 1;
		while systemIndex <= len(systemApps) {
			let appId = get(systemApps, systemIndex);
			let appRoot = concat("/apps/system/", appId);
			if statKind(appRoot) == "dir" {
				let manifestPath = concat(appRoot, "/taskbar.json");
				if exists(manifestPath) == true {
					let manifestArgs = listNew();
					push(manifestArgs, readFile(manifestPath));
					let manifest = libCall(jsonLib, "parse", manifestArgs);
					if mapGet(manifest, "taskbar") == true {
						push(taskbarAppIds, appId);
						let title = mapGet(manifest, "title");
						let letter = charAt(title, 1);
						if len(letter) == 0 {
							letter = charAt(appId, 1);
						}
						let buttonId = concat("taskbar_app_", taskbarIndex);
						guiButton(buttonId, "desktop_task_apps", letter, 0, 0, 0.055, 0.72);
						guiCorner(buttonId, 0);
						guiStylePreset(buttonId, styleLib, "task_button");
						taskbarIndex = taskbarIndex + 1;
					}
				}
			}
			systemIndex = systemIndex + 1;
		}

		let userAppsDir = concat(envGet("HOME"), "/apps");
		let userApps = listDir(userAppsDir);
		let userIndex = 1;
		while userIndex <= len(userApps) {
			let appId = get(userApps, userIndex);
			let appRoot = concat(concat(userAppsDir, "/"), appId);
			if statKind(appRoot) == "dir" {
				let manifestPath = concat(appRoot, "/taskbar.json");
				if exists(manifestPath) == true {
					let manifestArgs = listNew();
					push(manifestArgs, readFile(manifestPath));
					let manifest = libCall(jsonLib, "parse", manifestArgs);
					if mapGet(manifest, "taskbar") == true {
						push(taskbarAppIds, appId);
						let title = mapGet(manifest, "title");
						let letter = charAt(title, 1);
						if len(letter) == 0 {
							letter = charAt(appId, 1);
						}
						let buttonId = concat("taskbar_app_", taskbarIndex);
						guiButton(buttonId, "desktop_task_apps", letter, 0, 0, 0.055, 0.72);
						guiCorner(buttonId, 0);
						guiStylePreset(buttonId, styleLib, "task_button");
						taskbarIndex = taskbarIndex + 1;
					}
				}
			}
			userIndex = userIndex + 1;
		}

		if desktopAnimated == false {
			if envGet("ANIMATIONS") == "on" {
			guiTweenPreset("desktop_taskbar", "/lib/ui/motion.mxl", "desktop_taskbar_intro");
			}
			desktopAnimated = true;
		}

		let event = guiWait();
		let eventType = get(event, 1);
		let eventId = get(event, 2);
		let eventValue = get(event, 3);

		if eventType == "click" {
			if eventId == "desktop_logout" {
				onDesktop = false;
			} else {
				let launched = false;
				let lookupIndex = 1;
				while lookupIndex <= len(taskbarAppIds) {
					if eventId == concat("taskbar_app_", lookupIndex) {
						let appArgs = listNew();
						execAsync(get(taskbarAppIds, lookupIndex), appArgs);
						launched = true;
					}
					lookupIndex = lookupIndex + 1;
				}

			}
		} else {
			if eventType == "doubleclick" {
				let iconIndex = 1;
				while iconIndex <= len(desktopEntries) {
					if eventId == concat("desktop_icon_", iconIndex) {
						let shortcutName = get(desktopEntries, iconIndex);
						let shortcutPath = concat(concat(desktopDir, "/"), shortcutName);
						let shortcutParts = splitText(readFile(shortcutPath), "|");
						let appArgs = listNew();
						execAsync(get(shortcutParts, 1), appArgs);
					}
					iconIndex = iconIndex + 1;
				}
			} else {
				if eventType == "dragend" {
					let iconIndex = 1;
					while iconIndex <= len(desktopEntries) {
						if eventId == concat("desktop_icon_", iconIndex) {
							let shortcutName = get(desktopEntries, iconIndex);
							let shortcutPath = concat(concat(desktopDir, "/"), shortcutName);
							let shortcutParts = splitText(readFile(shortcutPath), "|");
							let newX = get(eventValue, 1);
							let newY = get(eventValue, 2);
							let shortcutValue = concat(get(shortcutParts, 1), "|");
							shortcutValue = concat(shortcutValue, get(shortcutParts, 2));
							shortcutValue = concat(shortcutValue, "|");
							shortcutValue = concat(shortcutValue, newX);
							shortcutValue = concat(shortcutValue, "|");
							shortcutValue = concat(shortcutValue, newY);
							writeFile(shortcutPath, shortcutValue);
						}
						iconIndex = iconIndex + 1;
					}
				}
			}
		}
	}
}
]]
