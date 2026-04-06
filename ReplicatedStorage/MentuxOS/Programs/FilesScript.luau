return [[
let styleLib = "/lib/ui/gui.mxl";
let currentPath = envGet("HOME");
let selectedPath = "";
let selectedKind = "";
let previewText = "Select a file to preview it here.";
let statusText = "Browsing your Mentux filesystem.";
let running = true;
let hasAnimated = false;

while running == true {
	guiReset();
	if envGet("THEME") == "light" {
		guiBackground("desktopLight");
	} else {
		guiBackground("desktop");
	}

	guiWindow("files_window", "Files", 0.5, 0.5, 0.86, 0.8);
	guiAnchor("files_window", 0.5, 0.5);
	guiStylePreset("files_window", styleLib, "window");
	guiLabel("files_title", "files_window", "Filesystem", 0.04, 0.1, 0.28, 0.07);
	guiLabel("files_path", "files_window", currentPath, 0.04, 0.16, 0.56, 0.06);
	guiLabel("files_status", "files_window", statusText, 0.62, 0.16, 0.32, 0.06);

	guiPanel("files_toolbar", "files_window", 0.04, 0.24, 0.92, 0.1, "panelMuted");
	guiStylePreset("files_toolbar", styleLib, "toolbar");
	guiPadding("files_toolbar", 0.02, 0.15, 0.02, 0.15);
	guiListLayout("files_toolbar", "horizontal", 0.015, "left", "center");
	guiButton("files_home", "files_toolbar", "Home", 0, 0, 0.14, 0.7);
	guiButton("files_up", "files_toolbar", "Up", 0, 0, 0.1, 0.7);
	guiButton("files_open", "files_toolbar", "Open", 0, 0, 0.14, 0.7);
	guiButton("files_refresh", "files_toolbar", "Refresh", 0, 0, 0.16, 0.7);
	guiButton("files_close", "files_toolbar", "Close", 0, 0, 0.14, 0.7);

	guiPanel("files_left", "files_window", 0.04, 0.37, 0.4, 0.56, "panel");
	guiPanel("files_right", "files_window", 0.48, 0.37, 0.48, 0.56, "panel");
	guiStylePreset("files_left", styleLib, "panel");
	guiStylePreset("files_right", styleLib, "panel");
	guiLabel("files_left_title", "files_left", "Entries", 0.05, 0.05, 0.4, 0.08);
	guiLabel("files_right_title", "files_right", "Preview", 0.05, 0.05, 0.4, 0.08);
	guiLabel("files_selected", "files_right", selectedPath, 0.05, 0.12, 0.9, 0.08);

	guiScrollFrame("files_entries", "files_left", 0.05, 0.16, 0.9, 0.76, 1.2);
	guiPadding("files_entries", 0.02, 0.02, 0.02, 0.02);
	guiListLayout("files_entries", "vertical", 0.015, "left", "top");
	guiTextArea("files_preview", "files_right", previewText, 0.05, 0.2, 0.9, 0.72);
	guiStylePreset("files_preview", styleLib, "text_surface");

	if hasAnimated == false {
		guiTweenPreset("files_window", "/lib/ui/motion.mxl", "files_window_intro");
		hasAnimated = true;
	}

	let entries = listDir(currentPath);
	let entryIndex = 1;
	while entryIndex <= len(entries) {
		let entryName = get(entries, entryIndex);
		let entryId = concat("files_entry_", entryIndex);
		guiButton(entryId, "files_entries", entryName, 0, 0, 0.96, 0.09);
		guiStylePreset(entryId, styleLib, "file_entry");
		entryIndex = entryIndex + 1;
	}

	let event = guiWait();
	let eventType = get(event, 1);
	let eventId = get(event, 2);
	let windowArgs = listNew();
	push(windowArgs, "files_window");
	push(windowArgs, eventType);
	push(windowArgs, eventId);
	let windowAction = libCall(styleLib, "handleWindowEvent", windowArgs);

	if eventType == "click" {
		if windowAction == "close" {
			running = false;
		} else {
			if windowAction != "handled" {
				if eventId == "files_close" {
					running = false;
				} else {
					if eventId == "files_home" {
						currentPath = envGet("HOME");
						statusText = "Returned to home.";
					} else {
						if eventId == "files_up" {
							currentPath = resolvePath(concat(currentPath, "/.."));
							statusText = concat("Moved to ", currentPath);
						} else {
							if eventId == "files_refresh" {
								statusText = concat("Refreshed ", currentPath);
							} else {
								if eventId == "files_open" {
									if len(selectedPath) == 0 {
										statusText = "Select an item first.";
									} else {
										if selectedKind == "dir" {
											let appMain = concat(selectedPath, "/main.mtx");
											if statKind(appMain) == "file" {
												let appArgs = listNew();
												execAsync(appMain, appArgs);
												statusText = concat("Launched app ", selectedPath);
											} else {
												currentPath = selectedPath;
												statusText = concat("Opened directory ", selectedPath);
											}
										} else {
											if selectedKind == "file" {
												let suffix = substr(selectedPath, len(selectedPath) - 3, 4);
												let suffix5 = substr(selectedPath, len(selectedPath) - 4, 5);
												let suffix7 = substr(selectedPath, len(selectedPath) - 6, 7);
												if suffix == ".mtx" {
													let appArgs = listNew();
													execAsync(selectedPath, appArgs);
													statusText = concat("Launched ", selectedPath);
												} else {
													if suffix == ".msh" {
														let codeArgs = listNew();
														push(codeArgs, selectedPath);
														execAsync("code", codeArgs);
														statusText = concat("Opened in Code ", selectedPath);
													} else {
														if suffix7 == ".mentux" {
															let codeArgs = listNew();
															push(codeArgs, selectedPath);
															execAsync("code", codeArgs);
															statusText = concat("Opened in Code ", selectedPath);
														} else {
															if suffix5 == ".luau" {
																let codeArgs = listNew();
																push(codeArgs, selectedPath);
																execAsync("code", codeArgs);
																statusText = concat("Opened in Code ", selectedPath);
															} else {
																if suffix5 == ".json" {
																	let codeArgs = listNew();
																	push(codeArgs, selectedPath);
																	execAsync("code", codeArgs);
																	statusText = concat("Opened in Code ", selectedPath);
																} else {
																	let noteArgs = listNew();
																	push(noteArgs, selectedPath);
																	execAsync("notepad", noteArgs);
																	statusText = concat("Opened in Notepad ", selectedPath);
																}
															}
														}
													}
												}
											} else {
												statusText = "Select an item first.";
											}
										}
									}
								} else {
									let lookupIndex = 1;
									while lookupIndex <= len(entries) {
										let lookupId = concat("files_entry_", lookupIndex);
										if eventId == lookupId {
											let entryName = get(entries, lookupIndex);
											let entryPath = resolvePath(concat(concat(currentPath, "/"), entryName));
											let entryKind = statKind(entryPath);
											selectedPath = entryPath;
											selectedKind = entryKind;
											if entryKind == "dir" {
												let appMain = concat(entryPath, "/main.mtx");
												if statKind(appMain) == "file" {
													previewText = concat("App bundle\n", fileInfo(appMain));
													statusText = concat("Selected app ", entryName);
												} else {
													previewText = "Directory selected. Use Open to enter it.";
													statusText = concat("Selected directory ", entryName);
												}
											} else {
												if entryKind == "file" {
													previewText = fileInfo(entryPath);
													statusText = concat("Selected file ", entryName);
												} else {
													previewText = "Item is no longer available.";
													statusText = concat("Missing item ", entryName);
												}
											}
										}
										lookupIndex = lookupIndex + 1;
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

exit(0);
]]
