local function forward(exportName, targetExport, arity)
	local lines = {
		"let callArgs = listNew();",
	}
	for index = 1, arity do
		table.insert(lines, string.format("if argc() >= %d {", index))
		table.insert(lines, string.format("\tpush(callArgs, argv(%d));", index))
		table.insert(lines, "}")
	end
	table.insert(lines, string.format('let result = libCall("/lib/ui/gui.mxl", "%s", callArgs);', targetExport or exportName))
	table.insert(lines, "libReturn(result);")
	return table.concat(lines, "\n")
end

return {
	["Gui.reset"] = forward("reset", "reset", 0),
	["Gui.background"] = forward("background", "setBackgroundPreset", 1),
	["Gui.panel"] = forward("panel", "panel", 7),
	["Gui.label"] = forward("label", "label", 7),
	["Gui.button"] = forward("button", "button", 7),
	["Gui.textBox"] = forward("textBox", "textBox", 10),
	["Gui.scrollFrame"] = forward("scrollFrame", "scrollFrame", 7),
	["Gui.textArea"] = forward("textArea", "textArea", 7),
	["Gui.richText"] = forward("richText", "richText", 7),
	["Gui.setText"] = forward("setText", "setText", 2),
	["Gui.getText"] = forward("getText", "getText", 1),
	["Gui.appendText"] = forward("appendText", "appendText", 2),
	["Gui.anchor"] = forward("anchor", "anchor", 3),
	["Gui.corner"] = forward("corner", "corner", 2),
	["Gui.padding"] = forward("padding", "padding", 5),
	["Gui.listLayout"] = forward("listLayout", "listLayout", 5),
	["Gui.backgroundTransparency"] = forward("backgroundTransparency", "backgroundTransparency", 2),
	["Gui.textTransparency"] = forward("textTransparency", "textTransparency", 2),
	["Gui.setBackgroundColor"] = forward("setBackgroundColor", "setBackgroundColor", 2),
	["Gui.setTextColor"] = forward("setTextColor", "setTextColor", 2),
	["Gui.setStrokeColor"] = forward("setStrokeColor", "setStrokeColor", 2),
	["Gui.setSize"] = forward("setSize", "setSize", 3),
	["Gui.setPosition"] = forward("setPosition", "setPosition", 3),
	["Gui.setVisible"] = forward("setVisible", "setVisible", 2),
	["Gui.setParent"] = forward("setParent", "setParent", 2),
	["Gui.setZIndex"] = forward("setZIndex", "setZIndex", 2),
	["Gui.setFont"] = forward("setFont", "setFont", 2),
	["Gui.setTextSize"] = forward("setTextSize", "setTextSize", 2),
	["Gui.setImage"] = forward("setImage", "setImage", 2),
	["Gui.tween"] = forward("tween", "tween", 7),
	["Gui.destroy"] = forward("destroy", "destroy", 1),
	["Gui.waitEvent"] = forward("waitEvent", "waitEvent", 0),
	["Gui.setDraggable"] = forward("setDraggable", "setDraggable", 3),
	["Gui.makeDraggable"] = forward("makeDraggable", "makeDraggable", 3),
	["Gui.setBackgroundPreset"] = forward("setBackgroundPreset", "setBackgroundPreset", 1),
	["Gui.applyStyle"] = forward("applyStyle", "applyStyle", 8),
	["Gui.applyStylePreset"] = forward("applyStylePreset", "applyStylePreset", 3),
	["Gui.stylePreset"] = forward("stylePreset", "applyStylePreset", 3),
	["Gui.tweenPreset"] = forward("tweenPreset", "tweenPreset", 3),
	["Gui.titleBar"] = forward("titleBar", "titleBar", 3),
	["Gui.closeButton"] = forward("closeButton", "closeButton", 7),
	["Gui.handleWindowEvent"] = forward("handleWindowEvent", "handleWindowEvent", 3),
	["Gui.window"] = forward("window", "window", 6),
	["Gui.desktopIcon"] = forward("desktopIcon", "desktopIcon", 6),
}
