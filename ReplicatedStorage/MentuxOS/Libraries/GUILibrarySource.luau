local function forward(syscallName, arity)
	local lines = {
		"let callArgs = listNew();",
	}
	for index = 1, arity do
		table.insert(lines, string.format("if argc() >= %d {", index))
		table.insert(lines, string.format("\tpush(callArgs, argv(%d));", index))
		table.insert(lines, "}")
	end
	table.insert(lines, string.format('let result = sysInvoke("%s", callArgs);', syscallName))
	table.insert(lines, "libReturn(result);")
	return table.concat(lines, "\n")
end

local exports = {
	reset = [[
libReturn(guiReset());
]],
	panel = forward("gui.panel", 7),
	label = forward("gui.label", 7),
	button = forward("gui.button", 7),
	textBox = forward("gui.textbox", 10),
	scrollFrame = forward("gui.scrollFrame", 7),
	textArea = forward("gui.textarea", 7),
	richText = forward("gui.richText", 7),
	setText = forward("gui.setText", 2),
	getText = forward("gui.getText", 1),
	appendText = forward("gui.appendText", 2),
	anchor = forward("gui.anchor", 3),
	corner = forward("gui.corner", 2),
	padding = forward("gui.padding", 5),
	listLayout = forward("gui.listLayout", 5),
	backgroundTransparency = forward("gui.backgroundTransparency", 2),
	textTransparency = forward("gui.textTransparency", 2),
	setBackgroundColor = forward("gui.setBackgroundColor", 2),
	setTextColor = forward("gui.setTextColor", 2),
	setStrokeColor = forward("gui.setStrokeColor", 2),
	setSize = forward("gui.setSize", 3),
	setPosition = forward("gui.setPosition", 3),
	setVisible = forward("gui.setVisible", 2),
	setParent = forward("gui.setParent", 2),
	setZIndex = forward("gui.setZIndex", 2),
	setFont = forward("gui.setFont", 2),
	setTextSize = forward("gui.setTextSize", 2),
	setImage = forward("gui.setImage", 2),
	tween = forward("gui.tween", 7),
	destroy = forward("gui.destroy", 1),
	waitEvent = [[
libReturn(guiWait());
]],
	setDraggable = forward("gui.setDraggable", 3),
	makeDraggable = forward("gui.setDraggable", 3),
	setBackgroundPreset = [[
let preset = "desktop";
if argc() >= 1 {
	preset = argv(1);
}

if preset == "login" {
	libReturn(guiSetBackgroundColor("", "login"));
}
if preset == "loginLight" {
	libReturn(guiSetBackgroundColor("", "loginLight"));
}
if preset == "desktopLight" {
	libReturn(guiSetBackgroundColor("", "desktopLight"));
}
if preset == "terminal" {
	libReturn(guiSetBackgroundColor("", "terminal"));
}

libReturn(guiSetBackgroundColor("", "desktop"));
]],
	applyStyle = [[
let id = argv(1);
if argc() >= 2 {
	guiSetBackgroundColor(id, argv(2));
}
if argc() >= 3 {
	guiSetTextColor(id, argv(3));
}
if argc() >= 4 {
	guiSetStrokeColor(id, argv(4));
}
if argc() >= 5 {
	guiCorner(id, toNumber(argv(5)));
}
if argc() >= 6 {
	guiBackgroundTransparency(id, toNumber(argv(6)));
}
if argc() >= 7 {
	guiTextTransparency(id, toNumber(argv(7)));
}
if argc() >= 8 {
	guiSetTextSize(id, toNumber(argv(8)));
}

libReturn(true);
]],
	applyStylePreset = [[
let id = argv(1);
let preset = "";
if argc() >= 3 {
	preset = argv(3);
} else {
	if argc() >= 2 {
		preset = argv(2);
	}
}

if preset == "login_shell" {
	guiSetBackgroundColor(id, "panelDark");
	guiBackgroundTransparency(id, 0.04);
	guiSetStrokeColor(id, "strokeStrong");
	guiCorner(id, 4);
}
if preset == "login_badge" {
	guiSetBackgroundColor(id, "taskbarSoft");
	guiBackgroundTransparency(id, 0.04);
	guiSetStrokeColor(id, "accent");
	guiCorner(id, 3);
	guiSetTextColor(id, "text");
}
if preset == "desktop_status" {
	guiSetBackgroundColor(id, "panelDark");
	guiBackgroundTransparency(id, 0.1);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 3);
}
if preset == "taskbar" {
	guiSetBackgroundColor(id, "taskbar");
	guiBackgroundTransparency(id, 0.02);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 0);
}
if preset == "task_strip" {
	guiSetBackgroundColor(id, "taskbar");
	guiBackgroundTransparency(id, 0.16);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 0);
}
if preset == "task_meta" {
	guiSetBackgroundColor(id, "panelMuted");
	guiBackgroundTransparency(id, 0.06);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 0);
}
if preset == "task_button" {
	guiSetBackgroundColor(id, "taskButton");
	guiBackgroundTransparency(id, 0.03);
	guiSetStrokeColor(id, "strokeStrong");
	guiCorner(id, 2);
	guiSetTextColor(id, "text");
}
if preset == "task_logout" {
	guiSetBackgroundColor(id, "accent");
	guiBackgroundTransparency(id, 0.02);
	guiSetStrokeColor(id, "#8C4B1D");
	guiCorner(id, 2);
	guiSetTextColor(id, "text");
}
if preset == "desktop_icon_button" {
	guiSetBackgroundColor(id, "panelDark");
	guiBackgroundTransparency(id, 0.18);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 3);
	guiTextTransparency(id, 1);
}
if preset == "desktop_icon_glyph" {
	guiSetTextColor(id, "accent");
	guiTextTransparency(id, 0);
	guiSetTextSize(id, 28);
}
if preset == "desktop_icon_label" {
	guiSetTextColor(id, "text");
	guiTextTransparency(id, 0);
	guiSetTextSize(id, 14);
}
if preset == "window" {
	guiSetBackgroundColor(id, "panel");
	guiBackgroundTransparency(id, 0.02);
	guiSetStrokeColor(id, "strokeStrong");
	guiCorner(id, 4);
}
if preset == "toolbar" {
	guiSetBackgroundColor(id, "panelMuted");
	guiBackgroundTransparency(id, 0.04);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 2);
}
if preset == "panel" {
	guiSetBackgroundColor(id, "panelDark");
	guiBackgroundTransparency(id, 0.03);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 3);
}
if preset == "text_surface" {
	guiSetBackgroundColor(id, "panelDark");
	guiBackgroundTransparency(id, 0.03);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 2);
	guiSetTextColor(id, "text");
}
if preset == "editor_surface" {
	guiSetBackgroundColor(id, "panelRaised");
	guiBackgroundTransparency(id, 0.02);
	guiSetStrokeColor(id, "strokeStrong");
	guiCorner(id, 2);
	guiSetTextColor(id, "text");
}
if preset == "file_entry" {
	guiSetBackgroundColor(id, "panelMuted");
	guiBackgroundTransparency(id, 0.03);
	guiSetStrokeColor(id, "stroke");
	guiCorner(id, 2);
	guiSetTextColor(id, "text");
}

libReturn(true);
]],
	tweenPreset = [[
let id = argv(1);
let preset = "";
if argc() >= 3 {
	preset = argv(3);
} else {
	if argc() >= 2 {
		preset = argv(2);
	}
}

if preset == "login_shell_intro" {
	guiSetPosition(id, 0.5, 0.56);
	libReturn(guiTween(id, "position", 0.5, 0.5, 0.24, "outCubic", 14));
}
if preset == "desktop_taskbar_intro" {
	guiSetPosition(id, 0.22, 0.92);
	libReturn(guiTween(id, "position", 0.22, 0.84, 0.2, "outQuad", 12));
}
if preset == "terminal_window_intro" {
	guiSetPosition(id, 0.1, 0.16);
	libReturn(guiTween(id, "position", 0.1, 0.1, 0.18, "outQuad", 10));
}

guiSetPosition(id, 0.5, 0.56);
libReturn(guiTween(id, "position", 0.5, 0.5, 0.2, "outCubic", 12));
]],
	titleBar = [[
let id = argv(1);
let parentId = argv(2);
let title = argv(3);

guiPanel(id, parentId, 0, 0, 1, 0.12, "taskbarSoft");
guiCorner(id, 4);
guiLabel(id + "_label", id, title, 0.04, 0.18, 0.82, 0.46);
guiSetTextColor(id + "_label", "text");
libReturn(true);
]],
	closeButton = [[
let id = argv(1);
let parentId = argv(2);
let text = "Close";
if argc() >= 3 {
	text = argv(3);
}
let x = 0.86;
let y = 0.02;
let width = 0.1;
let height = 0.08;
if argc() >= 7 {
	x = toNumber(argv(4));
	y = toNumber(argv(5));
	width = toNumber(argv(6));
	height = toNumber(argv(7));
}

guiButton(id, parentId, text, x, y, width, height);
let styleArgs = listNew();
push(styleArgs, id);
push(styleArgs, "task_logout");
libReturn(libCall("/lib/ui/gui.mxl", "applyStylePreset", styleArgs));
]],
	handleWindowEvent = [[
let windowId = argv(1);
let eventType = "";
let eventId = "";
if argc() >= 2 {
	eventType = argv(2);
}
if argc() >= 3 {
	eventId = argv(3);
}

let modeMenuId = windowId + "_sys_menu";
if eventType != "click" {
	libReturn("");
}

if eventId == windowId + "_sys_close" {
	libReturn("close");
}

if eventId == windowId + "_sys_mode" {
	guiSetVisible(modeMenuId, true);
	libReturn("handled");
}

if eventId == windowId + "_sys_drag" {
	guiSetDraggable(windowId + "_titlebar", true, windowId);
	guiSetVisible(modeMenuId, false);
	libReturn("handled");
}

if eventId == windowId + "_sys_fullscreen" {
	guiSetPosition(windowId, 0.5, 0.45);
	guiSetSize(windowId, 0.94, 0.82);
	guiSetVisible(modeMenuId, false);
	libReturn("handled");
}

if eventId == windowId + "_sys_minimize" {
	guiSetPosition(windowId, 0.2, 0.86);
	guiSetSize(windowId, 0.28, 0.12);
	guiSetVisible(modeMenuId, false);
	libReturn("handled");
}

guiSetVisible(modeMenuId, false);
libReturn("");
]],
	window = [[
let id = argv(1);
let title = argv(2);
let x = argv(3);
let y = argv(4);
let width = argv(5);
let height = argv(6);

guiPanel(id, "", x, y, width, height, "panel");
guiAnchor(id, 0.5, 0.5);
let styleArgs = listNew();
push(styleArgs, id);
push(styleArgs, "window");
libCall("/lib/ui/gui.mxl", "applyStylePreset", styleArgs);
let titleArgs = listNew();
push(titleArgs, id + "_titlebar");
push(titleArgs, id);
push(titleArgs, title);
libCall("/lib/ui/gui.mxl", "titleBar", titleArgs);
guiSetDraggable(id + "_titlebar", true, id);

let closeArgs = listNew();
push(closeArgs, id + "_sys_close");
push(closeArgs, id + "_titlebar");
push(closeArgs, "X");
push(closeArgs, 0.91);
push(closeArgs, 0.14);
push(closeArgs, 0.06);
push(closeArgs, 0.56);
libCall("/lib/ui/gui.mxl", "closeButton", closeArgs);

guiButton(id + "_sys_mode", id + "_titlebar", "[]", 0.84, 0.14, 0.06, 0.56);
let modeStyleArgs = listNew();
push(modeStyleArgs, id + "_sys_mode");
push(modeStyleArgs, "task_button");
libCall("/lib/ui/gui.mxl", "applyStylePreset", modeStyleArgs);

guiPanel(id + "_sys_menu", id, 0.69, 0.12, 0.27, 0.17, "panelMuted");
let menuStyleArgs = listNew();
push(menuStyleArgs, id + "_sys_menu");
push(menuStyleArgs, "toolbar");
libCall("/lib/ui/gui.mxl", "applyStylePreset", menuStyleArgs);
guiSetVisible(id + "_sys_menu", false);

guiButton(id + "_sys_drag", id + "_sys_menu", "Drag", 0.04, 0.14, 0.28, 0.66);
guiButton(id + "_sys_fullscreen", id + "_sys_menu", "Full", 0.36, 0.14, 0.28, 0.66);
guiButton(id + "_sys_minimize", id + "_sys_menu", "Mini", 0.68, 0.14, 0.28, 0.66);
libCall("/lib/ui/gui.mxl", "applyStylePreset", modeStyleArgs);
libReturn(true);
]],
	desktopIcon = [[
let id = argv(1);
let parentId = argv(2);
let label = argv(3);
let x = argv(4);
let y = argv(5);
let size = argv(6);
let height = toNumber(size) + 0.04;
let glyph = charAt(label, 1);
if len(glyph) == 0 {
	glyph = "?";
}

guiButton(id, parentId, "", x, y, size, height);
let buttonStyleArgs = listNew();
push(buttonStyleArgs, id);
push(buttonStyleArgs, "desktop_icon_button");
libCall("/lib/ui/gui.mxl", "applyStylePreset", buttonStyleArgs);
guiSetDraggable(id, true, id);
guiLabel(id + "_glyph", id, glyph, 0.18, 0.08, 0.64, 0.44);
let glyphArgs = listNew();
push(glyphArgs, id + "_glyph");
push(glyphArgs, "desktop_icon_glyph");
libCall("/lib/ui/gui.mxl", "applyStylePreset", glyphArgs);
guiLabel(id + "_label", id, label, 0.08, 0.58, 0.84, 0.28);
let labelArgs = listNew();
push(labelArgs, id + "_label");
push(labelArgs, "desktop_icon_label");
libCall("/lib/ui/gui.mxl", "applyStylePreset", labelArgs);
libReturn(true);
]],
}

return exports
