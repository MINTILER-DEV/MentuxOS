# Mentux OS Prototype

Mentux OS is a guest virtual computer implemented inside Roblox Studio. Luau is only the host language that emulates the hardware stack. Guest programs execute as Mentux VM instructions loaded from a custom executable image format instead of Luau source or Luau bytecode.

## Architecture

- `ReplicatedStorage/MentuxOS/CPU.luau` implements a register-based VM CPU with `R0` to `R7`, `IP`, `SP`, flags, a step function, a run loop, and optional tracing.
- `ReplicatedStorage/MentuxOS/Memory.luau` provides fixed-size virtual RAM with address-based reads and writes.
- `ReplicatedStorage/MentuxOS/ExecutableFormat.luau` defines the Mentux executable image structure with versioning, entry point, code, constants, and data sections.
- `ReplicatedStorage/MentuxOS/Loader.luau` maps executable sections into VM memory and relocates code and data references.
- `ReplicatedStorage/MentuxOS/VFS.luau` provides a tree-based virtual filesystem with `/boot`, `/bin`, `/etc`, and `/var`.
- `ReplicatedStorage/MentuxOS/KernelRuntime.luau` is the kernel host bridge that owns syscall dispatch, process creation, environment inheritance, PATH resolution, and child program execution.
- `ReplicatedStorage/MentuxOS/Compiler/Assembler.luau` is the in-game assembler-like frontend for turning Mentux assembly into guest executables.
- `ReplicatedStorage/MentuxOS/Compiler/MentuxScriptCompiler.luau` compiles MentuxScript into Mentux executable images inside the project.
- `ReplicatedStorage/MentuxOS/Client/GUIController.luau` is the generic Roblox GUI bridge used by guest applications.
- `ReplicatedStorage/MentuxOS/Programs/` contains the guest program sources for `kernel`, `init`, `gui`, `terminal`, `mci`, and `hello`.
- `External/Programs/*.mentux` contains plain MentuxScript source mirrors for the userland programs.

## Boot Flow

1. `StarterPlayerScripts/LocalScript.local.luau` calls `ReplicatedStorage/MentuxOS/Main.luau`.
2. `Main` builds a virtual disk from `ReplicatedStorage/MentuxOS/ExamplePrograms.luau`.
3. `Bootloader` mounts the VFS, looks up `/boot/kernel.mtx`, validates it, loads it into RAM, and transfers control to the kernel entry point.
4. The bootloader attaches the runtime to a generic GUI controller so guest applications can build Roblox UI through Mentux syscalls.
5. The guest kernel launches `/boot/init.mtx`, which seeds the test user under `/user/tester`, configures `PATH=/bin:/boot`, and starts `/bin/gui.mtx`.
6. `gui.mtx` is the guest session manager: it renders the login screen, authenticates against `/user/<username>/password.txt`, and shows the desktop.
7. The desktop launches `/bin/terminal.mtx`, which creates a single terminal window and then runs `/bin/mci.mtx` inside it.
8. User programs such as `/bin/hello.mtx` run in their own VM process, inherit the logged-in environment, and write back into the terminal app controls.

## Program Model

The kernel and user programs are both Mentux guest executables. The runtime seeds process registers with a simple calling convention:

- `R1`: argument count
- `R2`: argv payload
- `R3`: process path

Syscalls are centralized in `ReplicatedStorage/MentuxOS/KernelRuntime.luau`. The prototype includes:

- `write`
- `gui.reset`
- `gui.background`
- `gui.window`
- `gui.label`
- `gui.button`
- `gui.textbox`
- `gui.textarea`
- `gui.setText`
- `gui.getText`
- `gui.appendText`
- `gui.destroy`
- `gui.waitEvent`
- `value.len`
- `str.charAt`
- `str.substr`
- `str.concat`
- `list.new`
- `list.push`
- `list.get`
- `list.slice`
- `proc.argc`
- `proc.argv`
- `env.get`
- `env.set`
- `resolveExec`
- `resolvePath`
- `statKind`
- `readFile`
- `writeFile`
- `exists`
- `stat`
- `listDir`
- `exec`
- `exit`
- `halt`

Mentux processes inherit a simple environment table. `PATH`, `USER`, `HOME`, and `PWD` are guest-managed environment values. The default test login is auto-created in `init.mtx` at `/user/tester` with password `123456`, and the shell now resolves relative paths against `PWD`.

## Toolchain Direction

The current repo contains two compile paths:

- The runtime assembler in `ReplicatedStorage/MentuxOS/Compiler/Assembler.luau`, which is used to build the prototype kernel and user program.
- The external MentuxScript compiler in `External/MentuxCompiler.luau`, which shows the next step toward a real language toolchain that targets the same VM image format.

Next extensions for the compiler/toolchain are straightforward:

- add function declarations and `CALL` lowering
- add string/data pooling into the constants section
- introduce import/link steps for multi-file Mentux programs
- add process metadata and permission bits to executable images

## Testing

The prototype is structured to run from the Roblox Luau Env workflow. You can test it with `rle emulate-client`.
