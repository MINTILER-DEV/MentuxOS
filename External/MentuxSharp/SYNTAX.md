# Mentux Sharp (MT#) Draft Syntax Definition

Status: draft design only

Purpose:
- `.mentux`: compact, low-level-ish scripting for OS pieces, boot code, small tools
- `.msh`: higher-level MT# source for larger apps, richer structure, exceptions, classes, namespaces, and stronger library/program composition

This file defines a sample MT# syntax and source model. It is not implemented yet.

## File Types

- `.msh`
  Purpose: high-level Mentux Sharp source
  Typical use: large apps, reusable libraries, UI-heavy code

- `.mentux`
  Purpose: simpler Mentux source
  Typical use: shell tools, init, compact system programs

- `.mtx`
  Purpose: compiled executable image

- `.mxl`
  Purpose: compiled library image
  Rule: can export machine-code functions and constants, but cannot run standalone

## Design Goals

- Familiar C#/TypeScript-like structure
- Strong namespaces and classes
- Exceptions for big-app code
- Easy access to `.mxl` libraries
- Ability to embed existing `.mtx` executables inside MT# projects
- Keep guest-runtime semantics explicit

## Lexical Rules

- Comments:
  - single-line: `// comment`
  - block: `/* comment */`
- Statements end with `;`
- Blocks use `{ ... }`
- Identifiers:
  - `Name`
  - `_privateName`
  - `App.Window.Main`
- String literals:
  - `"hello"`
  - escapes: `\n`, `\t`, `\"`, `\\`
- Interpolated strings:
  - `$"Hello {userName}"`

## Top-Level Structure

Order:
1. `namespace`
2. `using`
3. `embed`
4. declarations (`const`, `enum`, `class`, `interface`, `function`)

Example:

```mtsharp
namespace Apps.Productivity.Notepad;

using System;
using System.IO;
using mxl Json = "/lib/core/json.mxl";
using mxl Motion = "/lib/ui/motion.mxl";

embed mtx LegacyShell from "../Programs/mci.mentux";
embed mtx RecoveryConsole from "/boot/recovery.mtx";

class AppMain {
    static int Main(string[] args) {
        return 0;
    }
}
```

## Namespaces

Syntax:

```mtsharp
namespace Apps.Productivity.Notepad;
```

Rules:
- One namespace per file
- Dot-separated hierarchy
- All declared symbols in the file belong to that namespace

## Using Directives

### Namespace Import

```mtsharp
using System;
using System.IO;
using Apps.Common.UI;
```

### Alias Import

```mtsharp
using IO = System.IO;
using EditorTheme = Apps.Common.UI.Theme;
```

### MXL Library Import

Syntax:

```mtsharp
using mxl Json = "/lib/core/json.mxl";
using mxl Motion = "../Libraries/ui-motion.mxl";
```

Meaning:
- binds a compiled `.mxl` library to an alias
- exported library symbols are accessed as members

Example:

```mtsharp
var doc = Json.parse(text);
var encoded = Json.stringify(doc);
Motion.play(window, "files_window_intro");
```

Compiler intent:
- `Json.parse(...)` lowers to library export invocation
- `Motion.play(...)` lowers to `.mxl` machine-code export invocation

## MTX Embedding

MT# can embed existing Mentux executables for launch, fallback, or packaging.

Syntax:

```mtsharp
embed mtx LegacyShell from "../Programs/mci.mentux";
embed mtx RecoveryTool from "/boot/recovery.mtx";
```

Access pattern:

```mtsharp
LegacyShell.exec(["help"]);
RecoveryTool.path;
```

Draft embedded object members:
- `.path`
- `.name`
- `.exec(args)`
- `.spawn(args)`

Use cases:
- launch a legacy `.mentux` tool from an MT# app
- bundle recovery or compatibility programs inside an MT# package

## Types

Primitive types:

```mtsharp
bool
int
float
string
void
object
```

System/container types:

```mtsharp
List<T>
Map<TKey, TValue>
Option<T>
Result<T, E>
```

Special runtime-oriented types:

```mtsharp
Process
Path
GuiNode
Exception
```

Type inference:

```mtsharp
var name = "tester";
var count = 4;
```

## Variables and Constants

```mtsharp
const string AppId = "notepad";
let string title = "Notepad";
var cursorLine = 1;
```

Meaning:
- `const`: compile-time constant
- `let`: mutable local with explicit type
- `var`: inferred local

## Functions

Syntax:

```mtsharp
function string NormalizePath(string input) {
    return input.trim();
}
```

Short form:

```mtsharp
function bool IsTextFile(string path) => path.endsWith(".txt");
```

Optional parameters:

```mtsharp
function void OpenFile(string path, bool readonly = false) {
}
```

## Classes

Syntax:

```mtsharp
class NotepadApp {
    private string currentPath;
    private string buffer;

    constructor(string path) {
        this.currentPath = path;
        this.buffer = "";
    }

    public void Open() {
    }

    public void Save() {
    }
}
```

Modifiers:
- `public`
- `private`
- `protected`
- `static`
- `abstract`

Inheritance:

```mtsharp
class NotepadApp : WindowApp {
}
```

Interfaces:

```mtsharp
interface IOpenable {
    void Open();
}

class FilesApp : WindowApp, IOpenable {
    public void Open() {
    }
}
```

## Enums

```mtsharp
enum OpenMode {
    Read,
    Write,
    Append
}
```

## Control Flow

```mtsharp
if (ready) {
} else {
}

while (running) {
}

for (let i = 0; i < files.count; i++) {
}

foreach (let file in files) {
}

switch (kind) {
    case "file":
        break;
    case "dir":
        break;
    default:
        break;
}
```

## Exceptions

MT# supports structured exception handling for app-scale code.

Syntax:

```mtsharp
try {
    var text = File.read(path);
}
catch (FileNotFoundException ex) {
    Logger.warn(ex.message);
}
catch (Exception ex) {
    Logger.error(ex.message);
}
finally {
    Logger.info("done");
}
```

Throwing:

```mtsharp
throw new InvalidOperationException("Document is read-only");
throw new FileNotFoundException(path);
```

User-defined exceptions:

```mtsharp
class DocumentException : Exception {
    constructor(string message) : base(message) {
    }
}
```

Compiler intent:
- exceptions may lower to result-checking/runtime trap tables
- syntax should stay high-level even if implementation uses explicit VM mechanisms

## Properties

Syntax:

```mtsharp
class Document {
    private string _title;

    public string Title {
        get { return _title; }
        set { _title = value; }
    }
}
```

Auto-property draft:

```mtsharp
public string Path { get; set; }
public bool Dirty { get; private set; }
```

## Collections and Object Literals

List literal:

```mtsharp
var names = ["a", "b", "c"];
```

Map/object literal:

```mtsharp
var manifest = {
    title: "Notepad",
    taskbar: true,
    appid: "notepad"
};
```

## Namespaced System APIs

Planned style:

```mtsharp
System.Console.write("Hello");
System.Process.spawn("/apps/system/notepad/main.mtx", []);
System.IO.File.write("/user/tester/note.txt", "hi");
System.Gui.Window.create("main");
```

This keeps MT# distinct from `.mentux`, where builtins are flatter and more direct.

## Async / Event Draft

Optional future syntax:

```mtsharp
async function void BootDesktop() {
    await Desktop.load();
}

event void OnClick(string controlId);
```

Not required for v1, but reserved.

## Entry Points

Executable entry:

```mtsharp
class Program {
    static int Main(string[] args) {
        return 0;
    }
}
```

Library export:

```mtsharp
namespace Libraries.Json;

class JsonExports {
    export static object parse(string source) {
        // implementation
    }

    export static string stringify(object value) {
        // implementation
    }
}
```

Draft compilation targets:
- `.msh` app -> `.mtx`
- `.msh` library -> `.mxl`

## Sample Conventions

- App entry class: `Program` or `AppMain`
- One public app class per file for UI-heavy sources
- Keep OS/bootstrap logic in `.mentux`
- Keep large desktop apps in `.msh`

## Example 1: App Using MXL and Embedded MTX

```mtsharp
namespace Apps.Tools.TerminalHost;

using System;
using mxl Motion = "/lib/ui/motion.mxl";
using mxl Json = "/lib/core/json.mxl";

embed mtx Shell from "../Programs/mci.mentux";

class TerminalHost {
    public int Run(string[] args) {
        var config = Json.parse("{\"title\":\"Terminal\"}");
        Motion.play("term_window", "terminal_window_intro");
        return Shell.exec(args);
    }
}
```

## Example 2: Exception-Based File Open

```mtsharp
namespace Apps.Productivity.Notepad;

using System.IO;

class NotepadApp {
    public string OpenDocument(string path) {
        try {
            return File.read(path);
        }
        catch (FileNotFoundException ex) {
            throw new DocumentException($"Document missing: {path}");
        }
    }
}
```

## Example 3: MXL Library Source Shape

```mtsharp
namespace Libraries.Json;

class JsonLibrary {
    export static object parse(string source) {
        return Runtime.Json.parse(source);
    }

    export static string stringify(object value) {
        return Runtime.Json.stringify(value);
    }
}
```

## Reserved Keywords

```text
namespace
using
embed
mtx
mxl
class
interface
enum
function
constructor
public
private
protected
static
abstract
export
const
let
var
if
else
while
for
foreach
switch
case
default
break
continue
return
try
catch
finally
throw
new
true
false
null
this
base
async
await
```

## Recommended Next Step

If this syntax direction looks right, the next practical step is:
1. lock the `.msh` grammar
2. decide the exact lowering model for classes/exceptions
3. define `.msh -> .mtx` and `.msh -> .mxl` compilation contracts
4. prototype one small MT# compiler in `External/`
