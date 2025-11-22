    .data

# 4096-bit A:
A:
    dword 0xffffffffffffffff
    zero 504

# 4096-bit B:
B:
    dword 0xffffffffffffffff
    zero 504

# 8192-bit result buffer: 128 dwords = 1024 bytes
RES:
    zero 1024

    .text

main:
    la x3, A          # pointer to A
    la x4, B          # pointer to B
    la x5, RES        # pointer to RES

    # load big integers into your bigmul unit
    ldbm x0, x3, x4 

    # perform 4096-bit x 4096-bit multiplication,
    # writing 8192-bit result to RES
    li x8,1
    bigmul x8, 0(x5)

    # exit
    li a7, 93         # ecall exit
    li a0, 0
    ecall
