return [[
.name mentux-kernel
.kind kernel
.stack 128
.const INIT_PATH = "/boot/init.mtx"
.entry start

start:
	LOADK R0, @INIT_PATH
	LOADK R1, "boot"
	SYSCALL "exec", R0, R1 => R2
	HALT
]]
