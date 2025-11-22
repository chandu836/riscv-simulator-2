.data

A:
    dword 0x7abcdef012345678
    dword 0x0123456789abcdef
    dword 0x1234567890abcdef
    dword 0x234567890abcdef0
    dword 0x34567890abcdef01
    dword 0x4567890abcdef012
    dword 0x567890abcdef0123
    dword 0x67890abcdef01234
    dword 0x7890abcdef012345
    dword 0x790abcdef0123456
    dword 0x70abcdef01234567
    dword 0x0abcdef012345678
    dword 0x1bcdef0123456789
    dword 0x2cdef01234567890
    dword 0x3def012345678901
    dword 0x4ef0123456789012
    dword 0x5f01234567890123
    dword 0x6012345678901234
    dword 0x7123456789012345
    dword 0x7234567890123456
    dword 0x7345678901234567
    dword 0x7456789012345678
    dword 0x7567890123456789
    dword 0x7678901234567890
    dword 0x7789012345678901
    dword 0x7890123456789012
    dword 0x7901234567890123
    dword 0x0123456789012345
    dword 0x1234567890123456
    dword 0x2345678901234567
    dword 0x3456789012345678
    dword 0x4567890123456789
    dword 0x5678901234567890
    zero 256

B:
    dword 0x13579bdf02468ace
    dword 0x2468ace13579bdf0
    dword 0x3579bdf02468ace1
    dword 0x468ace13579bdf02
    dword 0x579bdf02468ace13
    dword 0x68ace13579bdf024
    dword 0x79bdf02468ace135
    dword 0x7ace13579bdf0246
    dword 0x7bdf02468ace1357
    dword 0x7ce13579bdf02468
    dword 0x7df02468ace13579
    dword 0x7e13579bdf02468a
    dword 0x7f02468ace13579b
    dword 0x713579bdf02468ac
    dword 0x702468ace13579bd
    dword 0x02468ace13579bdf
    dword 0x13579bdf02468ace
    dword 0x2468ace13579bdf0
    dword 0x3579bdf02468ace1
    dword 0x468ace13579bdf02
    dword 0x579bdf02468ace13
    dword 0x68ace13579bdf024
    dword 0x79bdf02468ace135
    dword 0x7ace13579bdf0246
    dword 0x7bdf02468ace1357
    dword 0x7ce13579bdf02468
    dword 0x7df02468ace13579
    dword 0x7e13579bdf02468a
    dword 0x7f02468ace13579b
    dword 0x713579bdf02468ac
    dword 0x702468ace13579bd
    dword 0x02468ace13579bdf
    zero 256

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