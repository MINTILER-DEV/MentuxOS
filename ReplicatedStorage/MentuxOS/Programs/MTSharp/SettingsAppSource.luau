return [[
namespace Apps.System.Settings;

using System;
using System.Gui;
using System.String;

class SettingsApp {
    private string user;
    private string home;
    private string settingsDir;
    private string themePath;
    private string animationsPath;
    private string displayPath;
    private string usernamePath;
    private string passwordPath;
    private string themeValue;
    private string animationsValue;
    private string displayValue;
    private string usernameValue;
    private string passwordValue;
    private string statusText;
    private bool running;

    constructor() {
        this.user = Runtime.Env.get("USER");
        this.home = Runtime.Env.get("HOME");
        this.settingsDir = String.concat(this.home, "/settings");
        this.themePath = String.concat(this.settingsDir, "/theme.txt");
        this.animationsPath = String.concat(this.settingsDir, "/animations.txt");
        this.displayPath = String.concat(this.settingsDir, "/display.txt");
        this.usernamePath = String.concat(this.home, "/username.txt");
        this.passwordPath = String.concat(this.home, "/password.txt");
        this.themeValue = "dark";
        this.animationsValue = "on";
        this.displayValue = "100";
        this.usernameValue = this.user;
        this.passwordValue = "123456";
        this.statusText = "Settings loaded.";
        this.running = true;
        this.Load();
    }

    public void Load() {
        try {
            this.themeValue = File.read(this.themePath);
        }
        catch (FileNotFoundException ex) {
            this.themeValue = "dark";
        }

        try {
            this.animationsValue = File.read(this.animationsPath);
        }
        catch (FileNotFoundException ex) {
            this.animationsValue = "on";
        }

        try {
            this.displayValue = File.read(this.displayPath);
        }
        catch (FileNotFoundException ex) {
            this.displayValue = "100";
        }

        try {
            this.usernameValue = File.read(this.usernamePath);
        }
        catch (FileNotFoundException ex) {
            this.usernameValue = this.user;
        }

        try {
            this.passwordValue = File.read(this.passwordPath);
        }
        catch (FileNotFoundException ex) {
            this.passwordValue = "123456";
        }
    }

    public string BuildInstalledApps() {
        let installedApps = "System apps:\n";
        let systemApps = File.listDir("/apps/system");
        let systemIndex = 1;
        while (systemIndex <= Runtime.Value.len(systemApps)) {
            let appName = Runtime.List.get(systemApps, systemIndex);
            installedApps = String.concat(installedApps, " - ");
            installedApps = String.concat(installedApps, appName);
            installedApps = String.concat(installedApps, "\n");
            systemIndex = systemIndex + 1;
        }

        let userAppsDir = String.concat(this.home, "/apps");
        installedApps = String.concat(installedApps, "\nUser apps:\n");
        try {
            let userApps = File.listDir(userAppsDir);
            let userIndex = 1;
            while (userIndex <= Runtime.Value.len(userApps)) {
                let appName = Runtime.List.get(userApps, userIndex);
                installedApps = String.concat(installedApps, " - ");
                installedApps = String.concat(installedApps, appName);
                installedApps = String.concat(installedApps, "\n");
                userIndex = userIndex + 1;
            }
        }
        catch (DirectoryNotFoundException ex) {
            installedApps = String.concat(installedApps, " <none>\n");
        }

        return installedApps;
    }

    public string BuildSystemInfo() {
        let systemInfo = "User: ";
        systemInfo = String.concat(systemInfo, this.user);
        systemInfo = String.concat(systemInfo, "\nHome: ");
        systemInfo = String.concat(systemInfo, this.home);
        systemInfo = String.concat(systemInfo, "\nPID: ");
        systemInfo = String.concat(systemInfo, Runtime.Process.pid());
        systemInfo = String.concat(systemInfo, "\nTheme: ");
        systemInfo = String.concat(systemInfo, this.themeValue);
        systemInfo = String.concat(systemInfo, "\nAnimations: ");
        systemInfo = String.concat(systemInfo, this.animationsValue);
        systemInfo = String.concat(systemInfo, "\nDisplay Size: ");
        systemInfo = String.concat(systemInfo, this.displayValue);
        return systemInfo;
    }

    public void HandleClick(string eventId) {
        if (eventId == "settings_close") {
            this.running = false;
        } else {
            if (eventId == "settings_theme_light") {
                this.themeValue = "light";
                File.write(this.themePath, this.themeValue);
                this.statusText = "Theme set to light.";
            } else {
                if (eventId == "settings_theme_dark") {
                    this.themeValue = "dark";
                    File.write(this.themePath, this.themeValue);
                    this.statusText = "Theme set to dark.";
                } else {
                    if (eventId == "settings_toggle_animations") {
                        if (this.animationsValue == "on") {
                            this.animationsValue = "off";
                        } else {
                            this.animationsValue = "on";
                        }
                        File.write(this.animationsPath, this.animationsValue);
                        this.statusText = "Animations preference updated.";
                    } else {
                        if (eventId == "settings_save_display") {
                            this.displayValue = Gui.getText("settings_display");
                            File.write(this.displayPath, this.displayValue);
                            this.statusText = "Display size updated.";
                        } else {
                            if (eventId == "settings_save_username") {
                                this.usernameValue = Gui.getText("settings_username");
                                File.write(this.usernamePath, this.usernameValue);
                                this.statusText = "Display username updated.";
                            } else {
                                if (eventId == "settings_save_password") {
                                    this.passwordValue = Gui.getText("settings_password");
                                    File.write(this.passwordPath, this.passwordValue);
                                    this.statusText = "Password updated.";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public void RenderAccountPanel() {
        Gui.panel("settings_account", "settings_window", 0.04, 0.18, 0.42, 0.28, "panel");
        Gui.label("settings_username_label", "settings_account", "Display Username", 0.05, 0.08, 0.4, 0.1);
        Gui.textBox("settings_username", "settings_account", "username", this.usernameValue, 0.05, 0.2, 0.55, 0.16, false, false);
        Gui.button("settings_save_username", "settings_account", "Save Name", 0.64, 0.2, 0.28, 0.16);
        Gui.label("settings_password_label", "settings_account", "Password", 0.05, 0.48, 0.4, 0.1);
        Gui.textBox("settings_password", "settings_account", "password", this.passwordValue, 0.05, 0.6, 0.55, 0.16, true, false);
        Gui.button("settings_save_password", "settings_account", "Save Pass", 0.64, 0.6, 0.28, 0.16);
    }

    public void RenderAppearancePanel() {
        Gui.panel("settings_appearance", "settings_window", 0.5, 0.18, 0.44, 0.28, "panel");
        Gui.label("settings_theme_label", "settings_appearance", "Theme", 0.05, 0.08, 0.2, 0.1);
        Gui.button("settings_theme_light", "settings_appearance", "Light", 0.05, 0.2, 0.18, 0.16);
        Gui.button("settings_theme_dark", "settings_appearance", "Dark", 0.26, 0.2, 0.18, 0.16);
        Gui.label("settings_anim_label", "settings_appearance", "Animations", 0.05, 0.48, 0.24, 0.1);
        Gui.button("settings_toggle_animations", "settings_appearance", this.animationsValue, 0.26, 0.48, 0.18, 0.16);
        Gui.label("settings_display_label", "settings_appearance", "Display Size", 0.5, 0.08, 0.24, 0.1);
        Gui.textBox("settings_display", "settings_appearance", "display", this.displayValue, 0.5, 0.2, 0.22, 0.16, false, false);
        Gui.button("settings_save_display", "settings_appearance", "Apply", 0.74, 0.2, 0.18, 0.16);
    }

    public void RenderInfoPanel(string systemInfo) {
        Gui.panel("settings_info_panel", "settings_window", 0.04, 0.5, 0.42, 0.4, "panel");
        Gui.label("settings_info_label", "settings_info_panel", "System Information", 0.05, 0.06, 0.4, 0.08);
        Gui.textArea("settings_info", "settings_info_panel", systemInfo, 0.05, 0.16, 0.9, 0.74);
    }

    public void RenderAppsPanel(string installedApps) {
        Gui.panel("settings_apps_panel", "settings_window", 0.5, 0.5, 0.44, 0.4, "panel");
        Gui.label("settings_apps_label", "settings_apps_panel", "Installed Apps", 0.05, 0.06, 0.4, 0.08);
        Gui.textArea("settings_apps", "settings_apps_panel", installedApps, 0.05, 0.16, 0.9, 0.74);
    }

    public void RenderScreen(string installedApps, string systemInfo) {
        Gui.reset();
        if (this.themeValue == "dark") {
            Gui.background("login");
        } else {
            Gui.background("desktopLight");
        }

        Gui.window("settings_window", "Settings", 0.5, 0.5, 0.9, 0.84);
        Gui.anchor("settings_window", 0.5, 0.5);

        Gui.label("settings_title", "settings_window", "MentuxSharp Settings", 0.04, 0.09, 0.34, 0.06);
        Gui.label("settings_status", "settings_window", this.statusText, 0.56, 0.09, 0.38, 0.06);

        this.RenderAccountPanel();
        this.RenderAppearancePanel();
        this.RenderInfoPanel(systemInfo);
        this.RenderAppsPanel(installedApps);

        Gui.button("settings_close", "settings_window", "Close", 0.82, 0.92, 0.12, 0.06);
    }

    public int Run() {
        this.running = true;

        while (this.running == true) {
            let installedApps = this.BuildInstalledApps();
            let systemInfo = this.BuildSystemInfo();
            this.RenderScreen(installedApps, systemInfo);

            let event = Gui.waitEvent();
            let eventType = Runtime.List.get(event, 1);
            let eventId = Runtime.List.get(event, 2);

            if (eventType == "click") {
                let windowAction = Gui.handleWindowEvent("settings_window", eventType, eventId);
                if (windowAction == "close") {
                    this.running = false;
                } else {
                    if (windowAction != "handled") {
                        this.HandleClick(eventId);
                    }
                }
            }
        }

        return 0;
    }
}
]]
