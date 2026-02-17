const std = @import("std");

/// ============================================
/// CPU STATE (PURE DATA — NO BEHAVIOR)
/// ============================================
pub const Cpu = struct {
    /// 16 General Purpose Registers (R0–R15)
    /// R15 is Program Counter in real ARM,
    /// but in this simulation we track PC separately.
    regs: [16]u32 = [_]u32{0} ** 16,

    /// Current Program Status Register
    cpsr: u32 = 0x000000D3,
};

/// ============================================
/// Simulated Memory
/// ============================================
pub const Memory = struct {
    data: []u8,
};

/// ============================================
/// DECODED INSTRUCTION FORMAT
/// ============================================
pub const Instruction = union(enum) {
    ldr: struct { rd: u8, rn: u8, imm: u32 },
    mov: struct { rd: u8, imm: u32 },
    add: struct { rd: u8, rn: u8, imm: u32 },
    sub: struct { rd: u8, rn: u8, imm: u32 },
    bl: struct { target: usize },
};

/// ============================================
/// DECODE STAGE
/// Converts raw 32-bit ARM word into structured Instruction
/// ============================================
fn decode(word: u32) !Instruction {
    const type_bits = (word >> 26) & 0b11;

    // Data Processing instructions (bits 27–26 must be 00)
    if (type_bits == 0) {
        const opcode = (word >> 21) & 0xF;
        const rd: u8 = @intCast((word >> 12) & 0xF);
        const rn: u8 = @intCast((word >> 16) & 0xF);
        const i_bit = (word >> 25) & 1;

        // MOV (opcode 13)
        if (opcode == 13 and i_bit == 1) {
            const imm = word & 0xFF;
            return .{ .mov = .{ .rd = rd, .imm = imm } };
        }

        // ADD (opcode 4)
        if (opcode == 4 and i_bit == 1) {
            const imm = word & 0xFF;
            return .{ .add = .{ .rd = rd, .rn = rn, .imm = imm } };
        }

        // SUB (opcode 2)
        if (opcode == 2 and i_bit == 1) {
            const imm = word & 0xFF;
            return .{ .sub = .{ .rd = rd, .rn = rn, .imm = imm } };
        }
    }

    if (type_bits == 1) {
        const opcode = (word >> 21) & 0xF;
        const rd: u8 = @intCast((word >> 12) & 0xF);
        const rn: u8 = @intCast((word >> 16) & 0xF);
        const i_bit = (word >> 25) & 1;

        // LDR (opcode 12)
        if (opcode == 12 and i_bit == 0) {
            const imm = word & 0xFF;
            return .{ .ldr = .{ .rd = rd, .rn = rn, .imm = imm } };
        }
    }

    // Branch with Link (BL)
    // Bits 27–25 = 101
    if (((word >> 25) & 0b111) == 0b101) {
        const imm24 = word & 0x00FFFFFF;

        // Sign-extend 24-bit immediate
        const signed = @as(i32, @bitCast(imm24 << 8)) >> 6;

        return .{ .bl = .{ .target = @intCast(@as(isize, @divTrunc(signed, 4))) } };
    }

    return error.UnsupportedInstruction;
}

/// Decode entire program once (DOD style)
fn decodeProgram(
    raw: []const u32,
    allocator: std.mem.Allocator,
) ![]Instruction {
    var decoded = try allocator.alloc(Instruction, raw.len);

    for (raw, 0..) |word, i| {
        decoded[i] = try decode(word);
    }

    return decoded;
}

/// ============================================
/// DEBUG PRINT HELPERS
/// ============================================
fn printInstruction(inst: Instruction) void {
    switch (inst) {
        .mov => |i| std.debug.print("MOV R{d}, #{d}", .{ i.rd, i.imm }),
        .add => |i| std.debug.print("ADD R{d}, R{d}, #{d}", .{ i.rd, i.rn, i.imm }),
        .sub => |i| std.debug.print("SUB R{d}, R{d}, #{d}", .{ i.rd, i.rn, i.imm }),
        .ldr => |i| std.debug.print("SUB R{d}, R{d}, #{d}", .{ i.rd, i.rn, i.imm }),
        .bl => |i| std.debug.print("BL {d}", .{i.target}),
    }
}

fn dumpRegisters(cpu: *const Cpu) void {
    for (cpu.regs, 0..) |r, i| {
        std.debug.print("R{d: <2}: {d: <10}  ", .{ i, r });

        if ((i + 1) % 4 == 0)
            std.debug.print("\n", .{});
    }
}

/// ============================================
/// Helper Function to read from the file
/// ============================================
fn readU32(memory: []u8, addr: u32) u32 {
    return @as(u32, memory[addr]) |
        (@as(u32, memory[addr + 1]) << 8) |
        (@as(u32, memory[addr + 2]) << 16) |
        (@as(u32, memory[addr + 3]) << 24);
}

/// ============================================
/// EXECUTION STAGE (HOT LOOP)
/// ============================================
fn run(cpu: *Cpu, program: []Instruction) void {
    var pc: u32 = 0x10; // entry point
    var cycle: usize = 0;

    while (pc < program.len) {
        const inst = program[pc];

        std.debug.print(
            "\n==============================\n",
            .{},
        );
        std.debug.print("Cycle: {d}\n", .{cycle});
        std.debug.print("PC: {d}\n", .{pc});
        std.debug.print("Instruction: ", .{});
        printInstruction(inst);
        std.debug.print("\n\n", .{});

        // Execute instruction
        switch (inst) {
            .mov => |i| {
                cpu.regs[i.rd] = i.imm;
                pc += 1;
            },
            .add => |i| {
                cpu.regs[i.rd] = cpu.regs[i.rn] + i.imm;
                pc += 1;
            },
            .sub => |i| {
                cpu.regs[i.rd] = cpu.regs[i.rn] - i.imm;
                pc += 1;
            },
            .bl => |i| {
                // Save return address in R14 (Link Register)
                cpu.regs[14] = @intCast(pc + 1);

                // Branch
                pc = @intCast(i.target);
            },
        }

        dumpRegisters(cpu);

        cycle += 1;
    }
}

fn loop(memory: []u8) void {
    var cpu = Cpu{};
    var pc: u32 = 0x10; // entry point
    var cycle: usize = 0;

    while (cycle < 10) { // temporary limit
        const word = readU32(memory, pc);

        std.debug.print(
            "\n====================\nCycle: {d}\nPC: 0x{x}\nRaw: 0x{x}\n",
            .{ cycle, pc, word },
        );

        const inst = decode(word) catch {
            std.debug.print("Unsupported instruction\n", .{});
            break;
        };

        // Execute (we will expand this next)
        switch (inst) {
            .mov => |i| {
                cpu.regs[i.rd] = i.imm;
                pc += 4;
            },
            .add => |i| {
                cpu.regs[i.rd] = cpu.regs[i.rn] + i.imm;
                pc += 4;
            },
            .sub => |i| {
                cpu.regs[i.rd] = cpu.regs[i.rn] - i.imm;
                pc += 4;
            },
            else => {
                std.debug.print("Instruction not implemented yet\n", .{});
                //                break;
            },
        }

        dumpRegisters(&cpu);

        cycle += 1;
    }
}

/// ============================================
/// MAIN — SIMULATION ENTRY POINT
/// ============================================
pub fn main() !void {
    // var cpu = Cpu{};

    // Simulated ARM machine code
    //const raw_program = [_]u32{
    //    0xE3A0000A, // MOV R0, #10
    //    0xE3A0100B, // MOV R1, #11
    //    0xE2802005, // ADD R2, R0, #5
    //    0xE2403002, // SUB R3, R0, #2
    //};

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //const decoded = try decodeProgram(&raw_program, allocator);
    //defer allocator.free(decoded);

    //run(&cpu, decoded);
    const memory_size = 128 * 1024;
    const memory = try allocator.alloc(u8, memory_size);
    defer allocator.free(memory);
    @memset(memory, 0);

    // open main.bin
    const file_path = "bin/main.bin";
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.readAll(memory);

    std.debug.print("Loaded {d} bytes into memory.\n", .{file_size});

    loop(memory);
}
