.data
array:
    .word 2579, 756, 1026, 2439, 4671, 583, 3123, 1747, 2896, 4200, 2201, 4892, 3430, 3690, 2652, 1464, 927, 3146, 2587, 863, 4896, 1970, 3996, 890, 3039, 3025, 2047, 2727, 3005, 2705, 1924, 948, 1642, 4309, 2721, 3740, 1257, 3639, 4737, 1881, 1691, 561, 3958, 1388, 2627, 1774, 3120, 2927, 1201, 850, 2289, 2382, 2555, 2504, 1309, 2668, 4558, 1228, 2370, 3630, 763, 4249, 4663, 2320, 625, 3354, 4985, 1111, 4993, 4486, 4769, 4594, 3569, 921, 3263, 2996, 1234, 4824, 4351, 1899, 2873, 3526, 1434, 3772, 4986, 798, 782, 4354, 2412, 2157, 4046, 4121, 614, 2492, 4632, 3901, 4408, 3109, 3777, 836

.text
clip_array_baseline:
    # a0 = array address
    # a1 = array length
    # a2 = min_val
    # a3 = max_val
    la a0, array
    li a1, 100
    li a2, 1000
    li a3, 2000
    
    li      t0, 0               # i = 0
    
clip_loop_baseline:
    bge     t0, a1, clip_done_baseline
    slli    t1, t0, 2           # offset
    add     t1, t1, a0          # &array[i]
    lw      t2, 0(t1)           # val = array[i]
    
    # Clip to minimum
    bge     t2, a2, skip_min_baseline
    mv      t2, a2              # val = min_val
    
skip_min_baseline:
    bge     a3, t2, skip_max_baseline
    mv      t2, a3              # val = max_val
    
skip_max_baseline:
    sw      t2, 0(t1)           # array[i] = val
    addi    t0, t0, 1
    beq x0, x0, clip_loop_baseline
    
clip_done_baseline:
    add x0, x0, x0