.data

A:
    dword 0x499602d2,0x39447
    zero 504

B:
    dword 0x75bcd15
    zero 504


RES:
    zero 1024


.text
main:
    la x3, A
    la x4, B
    la x5, RES

    ldbm x0, x3, x4
    bigmul x0, 0(x5)

    li a7, 93
    li a0, 0
    ecall
