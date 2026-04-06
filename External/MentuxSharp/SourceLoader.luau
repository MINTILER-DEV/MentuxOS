local SourceLoader = {}

local FALLBACK_SAMPLES = {
	Launcher = [[
namespace Apps.Tools.Launcher;

using System;
using Libraries.Json;

embed mtx LegacyShell from "../Programs/mci.mentux";

class Launcher {
    static int Main(string[] args) {
        var manifest = Json.parse("{\"title\":\"Launcher\",\"taskbar\":true}");
        if (args.length > 0) {
            return LegacyShell.exec(args);
        }
        return 0;
    }
}
]],
	NotepadApp = [[
namespace Apps.Productivity.Notepad;

using System;
using System.IO;
using mxl Motion = "/lib/ui/motion.mxl";

class NotepadApp {
    private string currentPath;
    private string buffer;
    public bool Dirty { get; private set; }

    constructor(string path) {
        this.currentPath = path;
        this.buffer = "";
        this.Dirty = false;
    }

    public void Open() {
        try {
            this.buffer = File.read(this.currentPath);
            this.Dirty = false;
        }
        catch (FileNotFoundException ex) {
            this.buffer = "";
            this.Dirty = false;
        }
    }

    public void Save() {
        File.write(this.currentPath, this.buffer);
        this.Dirty = false;
    }

    public void SetText(string text) {
        this.buffer = text;
        this.Dirty = true;
    }

    public int Run() {
        Motion.play("notepad_window", "files_window_intro");
        this.Open();
        return 0;
    }
}
]],
	JsonLibrary = [[
namespace Libraries.Json;

class JsonLibrary {
    export static object parse(string source) {
        return Runtime.Json.parse(source);
    }

    export static string stringify(object value) {
        return Runtime.Json.stringify(value);
    }
}
]],
	ExceptionDemo = [[
namespace Demos.Exceptions;

using System;
using System.String;

class ExceptionDemo {
    static int Main(string[] args) {
        let output = "start";

        try {
            File.read("/missing/demo.txt");
            output = String.concat(output, "|unexpected");
        }
        catch (FileNotFoundException ex) {
            output = String.concat(output, "|missing");
        }
        finally {
            output = String.concat(output, "|cleanup");
        }

        try {
            throw "boom";
            output = String.concat(output, "|after-throw");
        }
        catch (Exception ex) {
            output = String.concat(output, "|throw");
        }
        finally {
            output = String.concat(output, "|done");
        }

        print(output);
        return 0;
    }
}
]],
}

local function sortedChildren(instance)
	local children = instance:GetChildren()
	table.sort(children, function(left, right)
		return left.Name < right.Name
	end)
	return children
end

local function collectSamples(container, samples)
	for _, child in ipairs(sortedChildren(container)) do
		if child:IsA("Folder") then
			collectSamples(child, samples)
		elseif child:IsA("StringValue") and child.Name:sub(-4) == ".msh" then
			samples[child.Name:sub(1, -5)] = child.Value
		end
	end
end

function SourceLoader.loadExternalSamples()
	local ok, root = pcall(function()
		return game:FindFirstChild("Examples")
	end)

	if not ok or root == nil then
		return {}
	end

	local samples = {}
	collectSamples(root, samples)
	return samples
end

function SourceLoader.loadSamples()
	local merged = {}

	for name, source in pairs(FALLBACK_SAMPLES) do
		merged[name] = source
	end

	for name, source in pairs(SourceLoader.loadExternalSamples()) do
		merged[name] = source
	end

	return merged
end

return SourceLoader
