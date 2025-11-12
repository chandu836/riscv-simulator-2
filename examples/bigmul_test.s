.data
A:  byte 56
    zero 511
B:  byte 23
    zero 511
RES: zero 1024

.text
main:
    # ABSOLUTE addresses (work even if 'la' is broken)
    li x3, 0x10000000   # A
    li x4, 0x10000200   # B
    li x5, 0x10000400   # RES

    ldbm x0, x3, x4
    bigmul x0, 0(x5)

    # (optional) exit
    li a7, 93
    li a0, 0
    ecall
