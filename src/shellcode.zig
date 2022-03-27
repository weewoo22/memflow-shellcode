comptime {
    asm (
        \\kernel_trampoline:
        \\  # Enter stage 2
        \\  movabs $0, %r8
        \\  callq  *%r8
        \\
        \\  nop
        \\_kernel_trampoline:
    );
}
pub extern fn kernel_trampoline() callconv(.Naked) noreturn;
pub extern fn _kernel_trampoline() callconv(.Naked) noreturn;

comptime {
    asm (
        \\blue_screen:
        \\  nop
        \\_blue_screen:
    );
}
pub extern fn blue_screen() callconv(.Naked) noreturn;
pub extern fn _blue_screen() callconv(.Naked) noreturn;
