local InstructionSet = {}

InstructionSet.Registers = {
	"R0",
	"R1",
	"R2",
	"R3",
	"R4",
	"R5",
	"R6",
	"R7",
}

InstructionSet.RegisterLookup = {}
for _, register in ipairs(InstructionSet.Registers) do
	InstructionSet.RegisterLookup[register] = true
end

InstructionSet.Ops = {
	NOP = "NOP",
	LOADK = "LOADK",
	MOV = "MOV",
	LOAD = "LOAD",
	STORE = "STORE",
	ADD = "ADD",
	SUB = "SUB",
	MUL = "MUL",
	DIV = "DIV",
	CMP = "CMP",
	JMP = "JMP",
	JMPIF = "JMPIF",
	PUSH = "PUSH",
	POP = "POP",
	CALL = "CALL",
	RET = "RET",
	SYSCALL = "SYSCALL",
	HALT = "HALT",
}

function InstructionSet.isRegister(value)
	return InstructionSet.RegisterLookup[value] == true
end

function InstructionSet.instruction(opcode, payload)
	local instruction = payload or {}
	instruction.op = opcode
	return instruction
end

return InstructionSet
