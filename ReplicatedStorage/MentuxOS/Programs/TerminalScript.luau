return [[
let styleLib = "/lib/ui/gui.mxl";
guiWindow("term_window", concat("Terminal - ", envGet("USER")), 0.1, 0.1, 0.8, 0.78);
guiStylePreset("term_window", styleLib, "window");
guiTweenPreset("term_window", "/lib/ui/motion.mxl", "terminal_window_intro");
guiLabel("term_header", "term_window", "Raw keyboard input is captured from UserInputService while this window is open.", 0.04, 0.12, 0.92, 0.07);
guiTextArea("term_output", "term_window", "", 0.04, 0.22, 0.92, 0.5);
guiStylePreset("term_output", styleLib, "text_surface");
guiPanel("term_input_shell", "term_window", 0.04, 0.75, 0.92, 0.11, "panelMuted");
guiStylePreset("term_input_shell", styleLib, "toolbar");
guiLabel("term_line", "term_input_shell", "", 0.03, 0.2, 0.94, 0.58);
guiLabel("term_footer", "term_window", "Enter runs, Backspace edits, Esc clears the line.", 0.04, 0.9, 0.72, 0.05);

envSet("TERM_OUTPUT", "term_output");
envSet("TERM_LINE", "term_line");

inputClear();
inputCapture();

let shellArgs = listNew();
let exitCode = exec("mci", shellArgs);

inputRelease();
guiDestroy("term_window");
exit(exitCode);
]]
