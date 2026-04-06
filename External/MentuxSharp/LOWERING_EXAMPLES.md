# MT# Lowering Examples

This file shows a few concrete `.msh -> IR/backend/image` examples using the current Mentux Sharp prototype compiler.

## Launcher

Source: `ExternalData/Examples/Launcher.msh`

```msh
namespace Apps.Tools.Launcher;

using System;
using mxl Json = "/lib/core/json.mxl";

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
```

Lowered IR shape:

```lua
IRModule {
  targetKind = "program",
  entryPoint = "Apps.Tools.Launcher.Launcher.Main",
  imports.libraries.Json = "/lib/core/json.mxl",
  embeds.LegacyShell = "../Programs/mci.mentux",
  functions = {
    Function {
      fullName = "Apps.Tools.Launcher.Launcher.Main",
      parameters = {
        { name = "args", parameterType = "string[]" },
      },
      body = {
        declare manifest = call_library(Json, "parse", { "{\"title\":\"Launcher\",\"taskbar\":true}" }),
        if binary(">", member_ref(local_ref("args"), "length"), literal(0)) then
          return call_embedded(LegacyShell, "exec", { local_ref("args") })
        end
        return literal(0)
      }
    }
  }
}
```

Backend/image result:

```text
target = program
entry  = Apps.Tools.Launcher.Launcher.Main
image  = Executable name=Launcher kind=program code=16 data=2
```

Key emitted behavior:

- parameter `args` is initialized from runtime `argv` (`R2`)
- `Json.parse(...)` becomes a real `SYSCALL json.parse`
- `LegacyShell.exec(args)` becomes a real `SYSCALL exec`
- returns become a real `SYSCALL exit`

## JsonLibrary

Source: `ExternalData/Examples/JsonLibrary.msh`

```msh
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

Lowered IR shape:

```lua
IRModule {
  targetKind = "library",
  exports = {
    parse = "Libraries.Json.JsonLibrary.parse",
    stringify = "Libraries.Json.JsonLibrary.stringify",
  },
  functions = {
    Function {
      fullName = "Libraries.Json.JsonLibrary.parse",
      parameters = {
        { name = "source", parameterType = "string" },
      },
      body = {
        return call_symbol({ "Runtime", "Json", "parse" }, { local_ref("source") })
      }
    },
    Function {
      fullName = "Libraries.Json.JsonLibrary.stringify",
      parameters = {
        { name = "value", parameterType = "object" },
      },
      body = {
        return call_symbol({ "Runtime", "Json", "stringify" }, { local_ref("value") })
      }
    }
  }
}
```

Backend/image result:

```text
target = library
image  = Library name=JsonLibrary kind=library exports=[parse, stringify]
```

Key emitted behavior:

- each exported MT# method becomes a real executable export image
- `Runtime.Json.parse` lowers to `SYSCALL json.parse`
- `Runtime.Json.stringify` lowers to `SYSCALL json.encode`
- library returns become a real `SYSCALL lib.return`

## ExceptionDemo

Source: `ExternalData/Examples/ExceptionDemo.msh`

```msh
namespace Demos.Exceptions;

using System;

class ExceptionDemo {
    static int Main(string[] args) {
        let output = "start";

        try {
            File.read("/missing/demo.txt");
            output = Runtime.String.concat(output, "|unexpected");
        }
        catch (FileNotFoundException ex) {
            output = Runtime.String.concat(output, "|missing");
        }
        finally {
            output = Runtime.String.concat(output, "|cleanup");
        }

        try {
            throw "boom";
            output = Runtime.String.concat(output, "|after-throw");
        }
        catch (Exception ex) {
            output = Runtime.String.concat(output, "|throw");
        }
        finally {
            output = Runtime.String.concat(output, "|done");
        }

        print(output);
        return 0;
    }
}
```

Lowered IR shape:

```lua
IRModule {
  targetKind = "program",
  entryPoint = "Demos.Exceptions.ExceptionDemo.Main",
  functions = {
    Function {
      fullName = "Demos.Exceptions.ExceptionDemo.Main",
      body = {
        declare output = literal("start"),
        try {
          tryBody = {
            expression call_symbol({ "File", "read" }, { literal("/missing/demo.txt") }),
            assign local_ref("output") = call_symbol({ "Runtime", "String", "concat" }, {
              local_ref("output"),
              literal("|unexpected"),
            }),
          },
          catches = {
            Catch {
              exceptionType = "FileNotFoundException",
              bindingName = "ex",
              body = {
                assign local_ref("output") = call_symbol({ "Runtime", "String", "concat" }, {
                  local_ref("output"),
                  literal("|missing"),
                }),
              },
            },
          },
          finallyBody = {
            assign local_ref("output") = call_symbol({ "Runtime", "String", "concat" }, {
              local_ref("output"),
              literal("|cleanup"),
            }),
          },
        },
        try {
          tryBody = {
            throw literal("boom"),
          },
          catches = {
            Catch {
              exceptionType = "Exception",
              bindingName = "ex",
              body = {
                assign local_ref("output") = call_symbol({ "Runtime", "String", "concat" }, {
                  local_ref("output"),
                  literal("|throw"),
                }),
              },
            },
          },
          finallyBody = {
            assign local_ref("output") = call_symbol({ "Runtime", "String", "concat" }, {
              local_ref("output"),
              literal("|done"),
            }),
          },
        },
        expression call_symbol({ "print" }, { local_ref("output") }),
        return literal(0),
      },
    },
  },
}
```

Backend/image result:

```text
target = program
entry  = Demos.Exceptions.ExceptionDemo.Main
image  = Executable name=ExceptionDemo kind=program
```

Key emitted behavior:

- `try/catch/finally` lowers to real control-flow labels plus pending-exception state
- throwing syscalls are wrapped through `safe.invoke(...)` when inside a protected region
- `throw "boom"` lowers to `exc.throw` and propagates into the nearest catch/finally region
- catch filtering uses `exc.peek` + `exc.match`, and matched exceptions are consumed with `exc.take`
- unhandled exceptions re-raise through `exc.raisePending`

## NotepadApp

Source: `ExternalData/Examples/NotepadApp.msh`

Current result:

```text
target = module
image  = Library name=NotepadApp kind=module exports=[NotepadApp.Open, NotepadApp.Run, NotepadApp.Save, NotepadApp.SetText, NotepadApp.ctor]
```

Lowered module shape:

```lua
IRModule {
  targetKind = "module",
  functions = {
    Function { fullName = "Apps.Productivity.Notepad.NotepadApp.ctor", ... },
    Function { fullName = "Apps.Productivity.Notepad.NotepadApp.Open", ... },
    Function { fullName = "Apps.Productivity.Notepad.NotepadApp.Save", ... },
    Function { fullName = "Apps.Productivity.Notepad.NotepadApp.SetText", ... },
    Function { fullName = "Apps.Productivity.Notepad.NotepadApp.Run", ... },
  }
}
```

Key emitted behavior:

- constructors now synthesize a real object table via `obj.new(typeName, proc.modulePath())`
- `this.field` reads and writes lower to `obj.get` / `obj.set`
- `this.Open()` lowers to an object-method dispatch through `obj.callMethod`
- the `try/catch` around `File.read(...)` now uses the same general exception path as the rest of MT#

## SettingsApp

Source: `ExternalData/Examples/SettingsApp.msh`

Current result:

```text
target = module
image  = Library name=SettingsApp kind=module exports=[SettingsApp.BuildInstalledApps, SettingsApp.BuildSystemInfo, SettingsApp.HandleClick, SettingsApp.Load, SettingsApp.RenderAccountPanel, SettingsApp.RenderAppearancePanel, SettingsApp.RenderAppsPanel, SettingsApp.RenderInfoPanel, SettingsApp.RenderScreen, SettingsApp.Run, SettingsApp.ctor]
```

Key emitted behavior:

- settings are stored as real object fields on a compiled `SettingsApp` instance
- file operations like `File.read`, `File.write`, and `File.listDir` participate in normal typed exception handling
- the UI-facing methods compile as separate executable exports, so large apps can be split into many smaller machine-code method bodies
- the app exercises most of the current MT# stack at once: classes, fields, constructors, method calls, strings, GUI syscalls, VFS, and typed exceptions

Current remaining limits:

- object-oriented MT# methods are executable, but they are still emitted as module-library exports rather than a dedicated class-image container
- exception types are currently matched by declared `__type`/name and runtime-captured syscall classes, not a full inheritance graph yet
