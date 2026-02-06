const std = @import("std");
const CPU = @import("cpu.zig");

pub fn main() !void {
    std.debug.print("Hello, {s}!\n", .{"World"});

    const insts = [_]u32{ 0xE3A0000A, 0xE3A0100B, 0xE3A04007, 0xE3A080CA };

    for (insts) |i| {
        var cpu = CPU.Cpu{};
        // 1. LOAD (The Cartridge)
        // We manually write 0xE3A0000A (MOV R0, #10) into memory at address 0.
        // Little Endian: Least significant byte goes to lowest address [11].
        // This writes the full 32-bit instruction (0xE3A0000A)
        // into the first 4 bytes of memory using Little Endian order.
        std.mem.writeInt(u32, cpu.memory[0..4], i, .little);
        std.debug.print("CPU Initialized. PC: {d}, R0: {any}\n", .{ cpu.regs[7], cpu.regs });

        // 2. Fetch
        const instruction = cpu.fetch();
        std.debug.print("FETCHED: 0x{X:0>8}\n", .{instruction});
        const rd = (instruction >> 12) & 0xF;

        // 3. DECODE & EXECUTE
        try cpu.execute(instruction);

        // 4. RESULT
        std.debug.print("CPU Result.      PC: {d}, R{d}: {any}\n", .{ cpu.regs[7], rd, cpu.regs });
    }
}
