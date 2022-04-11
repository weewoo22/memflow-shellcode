comptime {
    asm (
        \\kernel_trampoline:
        \\  call .+0x2291a8
        \\  nop
        \\_kernel_trampoline:
    );
}
pub extern fn kernel_trampoline() callconv(.Naked) noreturn;
pub extern fn _kernel_trampoline() callconv(.Naked) noreturn;

comptime {
    asm (
        \\stage_2: # nt+0x652bed
        \\  pushfq
        \\  # x64 pushad
        \\  # https://docs.microsoft.com/windows-hardware/drivers/debugger/x64-architecture#registers
        \\  pushq   %rax
        \\  pushq   %rbx
        \\  pushq   %rcx
        \\  pushq   %rdx
        \\  pushq   %rsi
        \\  pushq   %rdi
        \\  pushq   %rbp
        \\  pushq   %rsp
        \\  pushq   %r8
        \\  pushq   %r9
        \\  pushq   %r10
        \\  pushq   %r11
        \\  pushq   %r12
        \\  pushq   %r13
        \\  pushq   %r14
        \\  pushq   %r15
        \\
        \\  # TODO: allocate pages
        \\
        \\  popq    %r15
        \\  popq    %r14
        \\  popq    %r13
        \\  popq    %r12
        \\  popq    %r11
        \\  popq    %r10
        \\  popq    %r9
        \\  popq    %r8
        \\  popq    %rsp
        \\  popq    %rbp
        \\  popq    %rdi
        \\  popq    %rsi
        \\  popq    %rdx
        \\  popq    %rcx
        \\  popq    %rbx
        \\  popq    %rax
        \\  popfq
        \\
        \\start_reconcile_clobbers:
        \\  movq    %rcx, %rax
        \\  movzx   %dl, %edx
        \\end_reconcile_clobbers:
        \\  retq
        \\_stage_2:
    );
}
pub extern fn stage_2() callconv(.Naked) noreturn;
pub extern fn _stage_2() callconv(.Naked) noreturn;

comptime {
    asm (
        \\blue_screen:
        \\  nop
        \\_blue_screen:
    );
}
pub extern fn blue_screen() callconv(.Naked) noreturn;
pub extern fn _blue_screen() callconv(.Naked) noreturn;
