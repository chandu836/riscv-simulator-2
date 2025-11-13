.data
A:  byte 56
    zero 511
B:  byte 23
    zero 511
RES: zero 1024

.text
main:
    # Use relative addresses
    la x3, A    # Load actual address of A
    la x4, B    # Load actual address of B  
    la x5, RES  # Load actual address of RES

    ldbm x0, x3, x4
    bigmul x0, 0(x5)

    # (optional) exit
    li a7, 93
    li a0, 0
    ecall