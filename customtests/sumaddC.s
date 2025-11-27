.data

A:
    udword 0xFFFFFFFFFFFFFFFF
    udword 0xFFFFFFFFFFFFFFFF
    udword 0xFFFFFFFFFFFFFFFF
    udword 0x1111111111111111
    zero 480

B:
    udword 0x1
    udword 0x2
    udword 0x3
    udword 0xAAAAAAAAAAAAAAAA
    zero 480

R:
    zero 512

.text
main:

    # reset carry flag
    addC x0, x0, x0

    li t0, 0

loopC:
    # address = A + i*8
    mv t1, t0
    slli t1, t1, 3

    # load A[i]
    la t2, A
    add t2, t2, t1
    ld a0, 0(t2)

    # load B[i]
    la t3, B
    add t3, t3, t1
    ld a1, 0(t3)

    # ADDC handles carry automatically
    addC a2, a0, a1

    # store R[i]
    la t4, R
    add t4, t4, t1
    sd a2, 0(t4)

    addi t0, t0, 1
    li s8,64
    blt t0, s8, loopC

end:
    li a7, 93
    ecall
