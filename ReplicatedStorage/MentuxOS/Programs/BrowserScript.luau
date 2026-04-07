return [[
let styleLib = "/lib/ui/gui.mxl";
let webLib = "/lib/web/mtxdt.mxl";
let running = true;
let hasAnimated = false;
let currentUrl = "mtx://website.tux/";
let currentHost = "website.tux";
let currentTitle = "MtxDT Browser";
let currentStatus = "Ready.";
let currentBody = "Open an MtxDT URL such as mtx://website.tux/.";
let currentLinks = listNew();
let currentChannel = "";
let liveLog = "";

if argc() > 0 {
	currentUrl = argv(1);
}

while running == true {
	guiWindow("browser_window", "Browser", 0.5, 0.5, 0.9, 0.84);
	guiAnchor("browser_window", 0.5, 0.5);
	guiStylePreset("browser_window", styleLib, "window");
	guiLabel("browser_title", "browser_window", currentTitle, 0.04, 0.1, 0.52, 0.06);
	guiLabel("browser_status", "browser_window", currentStatus, 0.58, 0.1, 0.36, 0.06);

	guiPanel("browser_toolbar", "browser_window", 0.04, 0.18, 0.92, 0.1, "panelMuted");
	guiStylePreset("browser_toolbar", styleLib, "toolbar");
	guiTextBox("browser_url", "browser_toolbar", "mtx://host/", currentUrl, 0.02, 0.15, 0.58, 0.7, false, false);
	guiButton("browser_go", "browser_toolbar", "Go", 0.62, 0.15, 0.1, 0.7);
	guiButton("browser_refresh", "browser_toolbar", "Refresh", 0.74, 0.15, 0.12, 0.7);
	guiButton("browser_close", "browser_toolbar", "Close", 0.88, 0.15, 0.1, 0.7);

	guiPanel("browser_page_panel", "browser_window", 0.04, 0.31, 0.58, 0.53, "panel");
	guiStylePreset("browser_page_panel", styleLib, "panel");
	guiLabel("browser_page_title", "browser_page_panel", currentTitle, 0.04, 0.05, 0.9, 0.08);
	guiTextArea("browser_page_body", "browser_page_panel", currentBody, 0.04, 0.16, 0.92, 0.74);
	guiStylePreset("browser_page_body", styleLib, "text_surface");

	guiPanel("browser_links_panel", "browser_window", 0.65, 0.31, 0.31, 0.53, "panel");
	guiStylePreset("browser_links_panel", styleLib, "panel");
	guiLabel("browser_links_title", "browser_links_panel", "Links", 0.06, 0.05, 0.5, 0.08);
	guiScrollFrame("browser_links", "browser_links_panel", 0.06, 0.16, 0.88, 0.74, 1.1);
	guiPadding("browser_links", 0.02, 0.02, 0.02, 0.02);
	guiListLayout("browser_links", "vertical", 0.015, "left", "top");

	let linkIndex = 1;
	while linkIndex <= len(currentLinks) {
		let linkBlock = get(currentLinks, linkIndex);
		let linkId = concat("browser_link_", linkIndex);
		guiButton(linkId, "browser_links", objGet(linkBlock, "text"), 0, 0, 0.96, 0.12);
		guiStylePreset(linkId, styleLib, "file_entry");
		linkIndex = linkIndex + 1;
	}

	if len(currentChannel) > 0 {
		guiPanel("browser_live_panel", "browser_window", 0.04, 0.86, 0.92, 0.1, "panelMuted");
		guiStylePreset("browser_live_panel", styleLib, "toolbar");
		guiLabel("browser_live_label", "browser_live_panel", concat("Live Channel: ", currentChannel), 0.02, 0.14, 0.28, 0.5);
		guiTextBox("browser_live_input", "browser_live_panel", "message", "", 0.31, 0.15, 0.36, 0.62, false, false);
		guiButton("browser_live_send", "browser_live_panel", "Send", 0.69, 0.15, 0.1, 0.62);
		guiButton("browser_live_poll", "browser_live_panel", "Poll", 0.81, 0.15, 0.08, 0.62);
		guiButton("browser_live_clear", "browser_live_panel", "Clear", 0.9, 0.15, 0.08, 0.62);
		guiTextArea("browser_live_log", "browser_window", liveLog, 0.65, 0.86, 0.31, 0.1);
		guiStylePreset("browser_live_log", styleLib, "text_surface");
	}

	if hasAnimated == false {
		guiTweenPreset("browser_window", "/lib/ui/motion.mxl", "files_window_intro");
		hasAnimated = true;
	}

	let event = guiWait();
	let eventType = get(event, 1);
	let eventId = get(event, 2);
	let windowArgs = listNew();
	push(windowArgs, "browser_window");
	push(windowArgs, eventType);
	push(windowArgs, eventId);
	let windowAction = libCall(styleLib, "handleWindowEvent", windowArgs);

	if eventType == "click" {
		if windowAction == "close" {
			running = false;
		} else {
			if windowAction != "handled" {
				if eventId == "browser_close" {
					running = false;
				} else {
					let shouldLoad = false;
					if eventId == "browser_go" {
						currentUrl = guiGetText("browser_url");
						shouldLoad = true;
					} else {
						if eventId == "browser_refresh" {
							currentUrl = guiGetText("browser_url");
							shouldLoad = true;
						} else {
							if eventId == "browser_live_send" {
								let messageText = guiGetText("browser_live_input");
								if len(currentChannel) > 0 {
									let publishArgs = listNew();
									push(publishArgs, currentChannel);
									push(publishArgs, messageText);
									libCall(webLib, "Socket.Publish", publishArgs);
									currentStatus = "Published live message.";
								}
							} else {
								if eventId == "browser_live_clear" {
									liveLog = "";
									currentStatus = "Live log cleared.";
								} else {
									if eventId == "browser_live_poll" {
										let pollCount = 1;
										while pollCount <= 8 {
											let pollArgs = listNew();
											let message = libCall(webLib, "Socket.Poll", pollArgs);
											if message == false {
												pollCount = 9;
											} else {
												liveLog = concat(liveLog, concat(objGet(message, "sender"), ": "));
												liveLog = concat(liveLog, concat(objGet(message, "message"), "\n"));
											}
											pollCount = pollCount + 1;
										}
										currentStatus = "Polled live channel.";
									}
								}
							}
						}
					}

					let lookupIndex = 1;
					while lookupIndex <= len(currentLinks) {
						if eventId == concat("browser_link_", lookupIndex) {
							let linkHref = objGet(get(currentLinks, lookupIndex), "href");
							if charAt(linkHref, 1) == "/" {
								currentUrl = concat(concat("mtx://", currentHost), linkHref);
							} else {
								currentUrl = linkHref;
							}
							shouldLoad = true;
						}
						lookupIndex = lookupIndex + 1;
					}

					if shouldLoad == true {
						let requestArgs = listNew();
						push(requestArgs, currentUrl);
						let response = libCall(webLib, "Client.Get", requestArgs);
						let page = objGet(response, "page");
						currentTitle = objGet(page, "title");
						currentHost = objGet(response, "host");
						currentStatus = concat("Loaded ", currentUrl);
						currentBody = "";
						currentLinks = listNew();
						currentChannel = objGet(page, "channel");
						if currentChannel == false {
							currentChannel = "";
						}

						let blockIndex = 1;
						let blocks = objGet(page, "blocks");
						while blockIndex <= len(blocks) {
							let block = get(blocks, blockIndex);
							let kind = objGet(block, "kind");
							if kind == "heading" {
								currentBody = concat(currentBody, concat("# ", objGet(block, "text")));
								currentBody = concat(currentBody, "\n\n");
							} else {
								if kind == "text" {
									currentBody = concat(currentBody, objGet(block, "text"));
									currentBody = concat(currentBody, "\n\n");
								} else {
									if kind == "link" {
										push(currentLinks, block);
										currentBody = concat(currentBody, concat("-> ", objGet(block, "text")));
										currentBody = concat(currentBody, "\n");
									}
								}
							}
							blockIndex = blockIndex + 1;
						}

						if len(currentChannel) > 0 {
							let subscribeArgs = listNew();
							push(subscribeArgs, currentChannel);
							libCall(webLib, "Socket.Subscribe", subscribeArgs);
							liveLog = concat(liveLog, concat("[subscribed] ", currentChannel));
							liveLog = concat(liveLog, "\n");
						}
					}
				}
			}
		}
	}
}

exit(0);
]]
