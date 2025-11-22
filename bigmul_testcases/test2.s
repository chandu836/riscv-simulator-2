.data

A:
    dword 0x7aef13c7b4d26521
    dword 0x000deacb228afe46
    zero 496

B:
    dword 0x795da48769e024b2
    dword 0x00009be7adfc18cf
    zero 496

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
    bigmul x0, 0(x5) 

    # exit
    li a7, 93         # ecall exit
    li a0, 0
    ecall
