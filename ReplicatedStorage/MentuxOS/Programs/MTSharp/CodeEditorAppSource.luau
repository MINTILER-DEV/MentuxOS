return [[
namespace Apps.System.Code;

using System;
using System.Gui;
using System.String;

class CodeEditorApp {
    private string currentPath;
    private string buffer;
    private string highlighted;
    private string statusText;
    private string language;
    private bool running;
    private bool animated;
    private bool layoutReady;
    private bool previewDirty;

    constructor(string path) {
        this.currentPath = path;
        this.buffer = "";
        this.highlighted = "";
        this.statusText = "Ready.";
        this.language = "text";
        this.running = true;
        this.animated = false;
        this.layoutReady = false;
        this.previewDirty = false;
        this.Load();
    }

    public void Load() {
        try {
            this.buffer = File.read(this.currentPath);
            this.statusText = String.concat("Loaded ", this.currentPath);
        }
        catch (FileNotFoundException ex) {
            this.buffer = "";
            this.statusText = String.concat("New file ", this.currentPath);
        }

        this.DetectLanguage();
        this.RebuildHighlight();
        this.previewDirty = false;
    }

    public void Save() {
        File.write(this.currentPath, this.buffer);
        this.statusText = String.concat("Saved ", this.currentPath);
        this.previewDirty = false;
    }

    public void DetectLanguage() {
        let pathLength = Runtime.Value.len(this.currentPath);
        this.language = "text";

        let suffix4 = String.substr(this.currentPath, pathLength - 3, 4);
        let suffix5 = String.substr(this.currentPath, pathLength - 4, 5);
        let suffix7 = String.substr(this.currentPath, pathLength - 6, 7);

        if (suffix4 == ".msh") {
            this.language = "mtsharp";
        }
        if (suffix7 == ".mentux") {
            this.language = "mentux";
        }
        if (suffix5 == ".luau") {
            this.language = "luau";
        }
        if (suffix5 == ".json") {
            this.language = "json";
        }
        if (suffix4 == ".md") {
            this.language = "markdown";
        }
    }

    public string EscapeText(string text) {
        let result = "";
        let index = 1;
        let total = Runtime.Value.len(text);
        while (index <= total) {
            let ch = String.charAt(text, index);
            if (ch == "&") {
                result = String.concat(result, "&amp;");
            } else {
                if (ch == "<") {
                    result = String.concat(result, "&lt;");
                } else {
                    if (ch == ">") {
                        result = String.concat(result, "&gt;");
                    } else {
                        result = String.concat(result, ch);
                    }
                }
            }
            index = index + 1;
        }
        return result;
    }

    public string Colorize(string text, string color) {
        let result = "<font color=\"";
        result = String.concat(result, color);
        result = String.concat(result, "\">");
        result = String.concat(result, text);
        result = String.concat(result, "</font>");
        return result;
    }

    public bool IsLower(string ch) {
        if (ch >= "a") {
            if (ch <= "z") {
                return true;
            }
        }
        return false;
    }

    public bool IsUpper(string ch) {
        if (ch >= "A") {
            if (ch <= "Z") {
                return true;
            }
        }
        return false;
    }

    public bool IsDigit(string ch) {
        if (ch >= "0") {
            if (ch <= "9") {
                return true;
            }
        }
        return false;
    }

    public bool IsWordChar(string ch) {
        if (this.IsLower(ch) == true) {
            return true;
        }
        if (this.IsUpper(ch) == true) {
            return true;
        }
        if (this.IsDigit(ch) == true) {
            return true;
        }
        if (ch == "_") {
            return true;
        }
        return false;
    }

    public bool IsKeyword(string word) {
        if (word == "namespace") { return true; }
        if (word == "using") { return true; }
        if (word == "class") { return true; }
        if (word == "public") { return true; }
        if (word == "private") { return true; }
        if (word == "constructor") { return true; }
        if (word == "if") { return true; }
        if (word == "else") { return true; }
        if (word == "while") { return true; }
        if (word == "return") { return true; }
        if (word == "try") { return true; }
        if (word == "catch") { return true; }
        if (word == "finally") { return true; }
        if (word == "throw") { return true; }
        if (word == "let") { return true; }
        if (word == "true") { return true; }
        if (word == "false") { return true; }
        if (word == "null") { return true; }
        if (word == "bool") { return true; }
        if (word == "int") { return true; }
        if (word == "string") { return true; }
        if (word == "void") { return true; }
        return false;
    }

    public bool IsAccentPunctuation(string ch) {
        if (ch == "(") { return true; }
        if (ch == ")") { return true; }
        if (ch == "[") { return true; }
        if (ch == "]") { return true; }
        if (ch == "{") { return true; }
        if (ch == "}") { return true; }
        if (ch == ".") { return true; }
        if (ch == ",") { return true; }
        if (ch == ":") { return true; }
        if (ch == ";") { return true; }
        if (ch == "=") { return true; }
        if (ch == "+") { return true; }
        if (ch == "-") { return true; }
        if (ch == "*") { return true; }
        if (ch == "/") { return true; }
        return false;
    }

    public string HighlightLine(string line) {
        let result = "";
        let index = 1;
        let lineLength = Runtime.Value.len(line);

        while (index <= lineLength) {
            let ch = String.charAt(line, index);

            if (ch == "/") {
                let nextCh = String.charAt(line, index + 1);
                if (nextCh == "/") {
                    let commentText = String.substr(line, index, lineLength - index + 1);
                    result = String.concat(result, this.Colorize(this.EscapeText(commentText), "#6A9955"));
                    index = lineLength + 1;
                } else {
                    result = String.concat(result, this.Colorize(this.EscapeText(ch), "#DCDCAA"));
                    index = index + 1;
                }
            } else {
                if (ch == "\"") {
                    let token = "\"";
                    index = index + 1;
                    while (index <= lineLength) {
                        let stringCh = String.charAt(line, index);
                        token = String.concat(token, stringCh);
                        index = index + 1;
                        if (stringCh == "\"") {
                            break;
                        }
                    }
                    result = String.concat(result, this.Colorize(this.EscapeText(token), "#CE9178"));
                } else {
                    if (this.IsDigit(ch) == true) {
                        let numberToken = "";
                        while (index <= lineLength) {
                            let digitCh = String.charAt(line, index);
                            if (this.IsDigit(digitCh) == true) {
                                numberToken = String.concat(numberToken, digitCh);
                                index = index + 1;
                            } else {
                                if (digitCh == ".") {
                                    numberToken = String.concat(numberToken, digitCh);
                                    index = index + 1;
                                } else {
                                    break;
                                }
                            }
                        }
                        result = String.concat(result, this.Colorize(this.EscapeText(numberToken), "#B5CEA8"));
                    } else {
                        if (this.IsWordChar(ch) == true) {
                            let word = "";
                            while (index <= lineLength) {
                                let wordCh = String.charAt(line, index);
                                if (this.IsWordChar(wordCh) == true) {
                                    word = String.concat(word, wordCh);
                                    index = index + 1;
                                } else {
                                    break;
                                }
                            }
                            if (this.IsKeyword(word) == true) {
                                result = String.concat(result, this.Colorize(this.EscapeText(word), "#569CD6"));
                            } else {
                                result = String.concat(result, this.EscapeText(word));
                            }
                        } else {
                            if (this.IsAccentPunctuation(ch) == true) {
                                result = String.concat(result, this.Colorize(this.EscapeText(ch), "#DCDCAA"));
                            } else {
                                result = String.concat(result, this.EscapeText(ch));
                            }
                            index = index + 1;
                        }
                    }
                }
            }
        }

        return result;
    }

    public void RebuildHighlight() {
        let lines = String.split(this.buffer, "\n");
        let result = "";
        let index = 1;
        while (index <= Runtime.Value.len(lines)) {
            if (index > 1) {
                result = String.concat(result, "\n");
            }
            result = String.concat(result, this.HighlightLine(Runtime.List.get(lines, index)));
            index = index + 1;
        }
        this.highlighted = result;
    }

    public void EnsureLayout() {
        if (this.layoutReady == true) {
            return;
        }

        Gui.reset();
        if (Runtime.Env.get("THEME") == "dark") {
            Gui.background("login");
        } else {
            Gui.background("desktop");
        }

        Gui.window("code_window", "Code", 0.5, 0.5, 0.94, 0.88);
        Gui.anchor("code_window", 0.5, 0.5);

        Gui.label("code_title", "code_window", "MentuxSharp Code Editor", 0.04, 0.08, 0.34, 0.06);
        Gui.label("code_path", "code_window", this.currentPath, 0.04, 0.14, 0.52, 0.06);
        Gui.label("code_status", "code_window", this.statusText, 0.58, 0.14, 0.36, 0.06);
        Gui.label("code_lang", "code_window", String.concat("Language: ", this.language), 0.58, 0.08, 0.2, 0.06);

        Gui.panel("code_toolbar", "code_window", 0.04, 0.22, 0.92, 0.1, "panelMuted");
        Gui.padding("code_toolbar", 0.02, 0.15, 0.02, 0.15);
        Gui.listLayout("code_toolbar", "horizontal", 0.015, "left", "center");
        Gui.button("code_save", "code_toolbar", "Save", 0, 0, 0.14, 0.7);
        Gui.button("code_reload", "code_toolbar", "Reload", 0, 0, 0.14, 0.7);
        Gui.button("code_refresh", "code_toolbar", "Refresh Highlight", 0, 0, 0.22, 0.7);
        Gui.button("code_close", "code_toolbar", "Close", 0, 0, 0.14, 0.7);

        Gui.panel("code_editor_panel", "code_window", 0.04, 0.36, 0.44, 0.56, "panel");
        Gui.panel("code_preview_panel", "code_window", 0.52, 0.36, 0.44, 0.56, "panel");
        Gui.label("code_editor_label", "code_editor_panel", "Source", 0.05, 0.05, 0.4, 0.08);
        Gui.label("code_preview_label", "code_preview_panel", "Highlighted Preview", 0.05, 0.05, 0.64, 0.08);
        Gui.textBox("code_body", "code_editor_panel", "source", this.buffer, 0.05, 0.16, 0.9, 0.78, false, true);
        Gui.richText("code_preview", "code_preview_panel", this.highlighted, 0.05, 0.16, 0.9, 0.78);

        if (this.animated == false) {
            if (Runtime.Env.get("ANIMATIONS") == "on") {
                Gui.tweenPreset("code_window", "/lib/ui/motion.mxl", "files_window_intro");
            }
            this.animated = true;
        }

        this.layoutReady = true;
    }

    public void SyncEditorBody() {
        if (this.layoutReady == true) {
            Gui.setText("code_body", this.buffer);
        }
    }

    public void RefreshView() {
        if (this.layoutReady == false) {
            return;
        }

        Gui.setText("code_path", this.currentPath);
        Gui.setText("code_status", this.statusText);
        Gui.setText("code_lang", String.concat("Language: ", this.language));
        Gui.setText("code_preview", this.highlighted);
    }

    public int Run() {
        this.EnsureLayout();
        this.SyncEditorBody();
        this.RefreshView();

        while (this.running == true) {
            let event = Gui.waitEvent();
            let eventType = Runtime.List.get(event, 1);
            let eventId = Runtime.List.get(event, 2);
            let windowAction = Gui.handleWindowEvent("code_window", eventType, eventId);

            if (eventType == "click") {
                if (windowAction == "close") {
                    this.running = false;
                } else {
                    if (windowAction != "handled") {
                        if (eventId == "code_close") {
                            this.running = false;
                        } else {
                            if (eventId == "code_reload") {
                                this.Load();
                                this.SyncEditorBody();
                                this.RefreshView();
                            } else {
                                if (eventId == "code_save") {
                                    this.buffer = Gui.getText("code_body");
                                    this.RebuildHighlight();
                                    this.Save();
                                    this.RefreshView();
                                } else {
                                    if (eventId == "code_refresh") {
                                        this.buffer = Gui.getText("code_body");
                                        this.RebuildHighlight();
                                        this.previewDirty = false;
                                        this.statusText = "Highlight refreshed.";
                                        this.RefreshView();
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                if (eventId == "code_body") {
                    if (eventType == "change") {
                        this.buffer = Gui.getText("code_body");
                        this.previewDirty = true;
                        this.statusText = "Editing... preview is stale.";
                        Gui.setText("code_status", this.statusText);
                    } else {
                        if (eventType == "submit") {
                            this.buffer = Gui.getText("code_body");
                            this.RebuildHighlight();
                            this.previewDirty = false;
                            this.statusText = "Preview updated.";
                            this.RefreshView();
                        }
                    }
                }
            }
        }

        return 0;
    }
}
]]
