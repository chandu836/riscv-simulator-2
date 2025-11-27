.data

# A: 64 limbs of 64-bit numbers
A:
    # first few non-zero to test carry chain
    udword 0xFFFFFFFFFFFFFFFF
    udword 0xFFFFFFFFFFFFFFFF
    udword 0xFFFFFFFFFFFFFFFF
    udword 0x1111111111111111
    # rest 60 limbs zero
    zero 480

# B: 64 limbs
B:
    udword 0x1
    udword 0x2
    udword 0x3
    udword 0xAAAAAAAAAAAAAAAA
    zero 480

R:
    zero 512      # store 64 limbs result


.text
main:

    li t0, 0              # i = 0 loop counter

loop:
    # load A[i]
    mv t1, t0
    slli t1, t1, 3         # *8
    la t2, A
    add t2, t2, t1
    ld a0, 0(t2)

    # load B[i]
    la t3, B
    add t3, t3, t1
    ld a1, 0(t3)

    # sum
    add a2, a0, a1

    # carry detection
    sltu a3, a2, a0

    # store sum
    la t4, R
    add t4, t4, t1
    sd a2, 0(t4)

    # store carry to next limb (add into next iteration)
    addi t0, t0, 1
    li s8, 64
    blt t0, s8, loop

end:  
    li a7, 93
    ecall
