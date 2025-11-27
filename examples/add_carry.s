.data
A:
    udword 0xffffffffffffffff
    zero 504

B:
    udword 0xffffffffffffffff
    zero 504

RES:
    zero 512

.text
main:
    la      x10, A
    la      x11, B
    la      x12, RES

    li      x6, 0
    addC    x6, x6, x0

    li      x7, 2

loop:
    ld      x1, 0(x10)
    ld      x2, 0(x11)

    addC    x3, x1, x2
    sd      x3, 0(x12)

    addi    x10, x10, 8
    addi    x11, x11, 8
    addi    x12, x12, 8

    addi    x7, x7, -1
    bne     x7, x0, loop      # <--- FIXED

    li      a7, 93
    li      a0, 0
    ecall
