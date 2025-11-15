# Ripes-compatible RV64 BIGMUL (64 limbs x 64 limbs)
# ABI-clean: uses only t0..t6 and a0..a6 as temps

.data

# A: 64 limbs (8 bytes each). Example two non-zero limbs, rest zero
A:
    .dword 0x499602d2
    .dword 0x39447
    .zero 496

# B: 64 limbs
B:
    .dword 0x75bcd15
    .zero 504

# RES: 128 limbs (result)
RES:
    .zero 1024

.text
.global main

main:
    # set base pointers
    la    a0, A        # a0 -> &A[0]
    la    a1, B        # a1 -> &B[0]
    la    a2, RES      # a2 -> &RES[0]

    li    t0, 0        # i = 0

loop_i:
    li    t1, 0        # j = 0

loop_j:
    # compute address of A[i] and load A[i] into t4
    mv    t2, t0
    slli  t2, t2, 3
    add   t2, a0, t2
    ld    t4, 0(t2)

    # compute address of B[j] and load B[j] into t5
    mv    t2, t1
    slli  t2, t2, 3
    add   t2, a1, t2
    ld    t5, 0(t2)

    # 128-bit product: low in t6, high in t3
    mul   t6, t4, t5
    mulh  t3, t4, t5

    # k = i + j  (index)
    add   t2, t0, t1    # reuse t2 for k

    # a3 = address of RES[k]
    mv    a3, t2
    slli  a3, a3, 3
    add   a3, a2, a3

    # load RES[k] into a4
    ld    a4, 0(a3)

    # sum_low = a4 + t6
    add   a5, a4, t6
    sd    a5, 0(a3)     # store new RES[k]

    # carry1 = (sum_low < low)  (unsigned)
    sltu  a6, a5, t6    # a6 = 0 or 1

    # carry = high + carry1  -> store in a6
    add   a6, t3, a6

    # if carry == 0 skip propagation
    beqz  a6, skip_propagate

propagate_loop:
    # increment index k (t2 = k+1)
    addi  t2, t2, 1

    # a3 = &RES[k] (address for next limb)
    mv    a3, t2
    slli  a3, a3, 3
    add   a3, a2, a3

    # load RES[k], add carry, store back; update carry
    ld    a4, 0(a3)
    add   a5, a4, a6
    sd    a5, 0(a3)

    # new_carry = (a5 < previous_carry)  (unsigned)
    sltu  a6, a5, a6

    # continue if carry still non-zero
    bnez  a6, propagate_loop

skip_propagate:
    # j++
    addi  t1, t1, 1
    li    t2, 64
    blt   t1, t2, loop_j

    # i++
    addi  t0, t0, 1
    li    t2, 64
    blt   t0, t2, loop_i

# finished - spin here so you can inspect RES in Ripes memory viewer
end:
    li a7, 93
    ecall
