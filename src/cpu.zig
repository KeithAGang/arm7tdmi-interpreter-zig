const std = @import("std");

pub const Cpu = struct {
    // 1. The registers (r0-r15)
    // We initialize them to 0
    regs: [16]u32 = [_]u32{0} ** 16,

    // 2. The Status Register (CPSR)
    // We initialize it to Supervisor Mode (0x13) with interrupts disabled (0xD3)
    // to match the hardware Reset behavior
    cpsr: u32 = 0x000000D3,

    // 3. The Memory
    // 64kb of zeroed RAM.
    memory: [64 * 1024]u8 = [_]u8{0} ** (64 * 1024),

    // Helper to get the Program Counter easily
    pub fn getPC(self: *const Cpu) u32 {
        return self.regs[15];
    }

    // Helper to advance PC, usually by 4 bytes
    pub fn incPC(self: *Cpu) void {
        self.regs[15] += 4;
    }

    // Fetch Instruction
    pub fn fetch(self: *Cpu) u32 {
        const pc = self.getPC();

        // ARM7TDMI fetches words (32-bit) aligned to 4-byte boundaries
        // We use Little-Endian by default
        const inst = std.mem.readInt(u32, self.memory[pc..][0..4], .little);

        // Advance PC by 4 bytes ie size of one arm Instruction
        self.incPC();

        return inst;
    }

    // Executing The Instruction
    pub fn execute(self: *Cpu, inst: u32) !void {
        // Bits 27-26: Must be '00' for Data Processing
        const type_bits = (inst >> 26) & 0b11;

        if (type_bits == 0) {
            // It is a data processing Instruction

            // Extract Opcode (Bits 24-21)
            const opcode = (inst >> 21) & 0xF;

            // Extract Destination Register Rd (Bits 15-12)
            const rd = (inst >> 12) & 0xF;

            // Extract I-Bit (Bit 25) - Is operand 2 an immediate?
            const i_bit = (inst >> 25) & 1;

            // Execute Stage
            // Check For MOV (opcode 1101 = 13)
            if (opcode == 13) {
                var result: u32 = 0;

                if (i_bit == 1) {
                    // Immediate Mode
                    // Bits 7-0 are the value
                    // We are ignoring the rotate bits 11-8 for this sample
                    const imm = inst & 0xFF;
                    result = imm;
                } else {
                    // Register Mode, //TODO immplement this later
                    return error.undefined;
                }

                // Write back to Register File
                self.regs[rd] = result;
                std.debug.print("EXEC: MOV R{d}, #{d}\n", .{ rd, result });
            }
        }
    }
};
