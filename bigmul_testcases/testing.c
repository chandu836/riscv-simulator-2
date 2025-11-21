#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include <inttypes.h>

#define ARRAY_SIZE 64      // 64 limbs
typedef uint64_t bignum_t[ARRAY_SIZE];

// Generate random 64-bit limbs
void generate_random_bignum(bignum_t num) {
    for (int i = 0; i < ARRAY_SIZE; i++) {
        uint64_t v = (((uint64_t)rand() & 0xffffffffULL) << 32)
                   | ((uint64_t)rand() & 0xffffffffULL);
        num[i] = v;
    }
}

// Write A, B, RES to assembly file – using 64-bit dword
void write_assembly_file(bignum_t a, bignum_t b) {
    FILE *fp = fopen("bignum_data.s", "w");
    if (!fp) {
        perror("Failed to open file");
        exit(1);
    }

    fprintf(fp, "# Auto-generated 4096-bit values for simulator\n\n");
    fprintf(fp, ".data\n\n");

    // --- A ---
    fprintf(fp, "A:\n");
    for (int i = 0; i < ARRAY_SIZE; i++) {
        fprintf(fp, "    dword 0x%016" PRIx64 "\n", a[i]);
    }

    // --- B ---
    fprintf(fp, "B:\n");
    for (int i = 0; i < ARRAY_SIZE; i++) {
        fprintf(fp, "    dword 0x%016" PRIx64 "\n", b[i]);
    }

    // --- RES buffer (1024 bytes = 128 * 8 bytes) ---
    fprintf(fp, "RES:\n");
    fprintf(fp, "    .zero 1024\n");

    // Program
    fprintf(fp, "\n.text\n");
    fprintf(fp, "main:\n");
    fprintf(fp, "    la x3, A\n");
    fprintf(fp, "    la x4, B\n");
    fprintf(fp, "    la x5, RES\n");
    fprintf(fp, "    ldbm x0, x3, x4\n");
    fprintf(fp, "    bigmul x0, 0(x5)\n");
    fprintf(fp, "    li a7, 93\n");
    fprintf(fp, "    li a0, 0\n");
    fprintf(fp, "    ecall\n");

    fclose(fp);
}

// Classic schoolbook multiplication (correct)
void multiply_bignum(bignum_t a, bignum_t b, uint64_t *result) {
    for (int i = 0; i < ARRAY_SIZE * 2; i++)
        result[i] = 0;

    for (int i = 0; i < ARRAY_SIZE; i++) {
        __uint128_t carry = 0;
        for (int j = 0; j < ARRAY_SIZE; j++) {
            __uint128_t prod = (__uint128_t)a[i] * (__uint128_t)b[j];
            __uint128_t sum = prod + result[i + j] + carry;

            result[i + j] = (uint64_t)sum;
            carry = sum >> 64;
        }
        result[i + ARRAY_SIZE] += (uint64_t)carry;
    }
}

// Print big num MSW → LSW
void print_bignum(const char *label, uint64_t *num, int size) {
    printf("%s:\n0x", label);
    int start = size - 1;
    while (start > 0 && num[start] == 0)
        start--;

    printf("%" PRIx64 "\n", num[start]);
    for (int i = start - 1; i >= 0; i--)
        printf("%016" PRIx64 "\n", num[i]);

    printf("\n");
}

int count_bits(uint64_t *num, int size) {
    int hi = size - 1;
    while (hi > 0 && num[hi] == 0)
        hi--;

    uint64_t v = num[hi];
    int bits = 0;
    while (v) { v >>= 1; bits++; }
    return hi * 64 + bits;
}

int main() {
    bignum_t a, b;
    uint64_t result[ARRAY_SIZE * 2];

    srand(time(NULL));

    printf("=== 4096-bit Number Multiplication Tester ===\n\n");

    generate_random_bignum(a);
    generate_random_bignum(b);

    print_bignum("Number A", a, ARRAY_SIZE);
    print_bignum("Number B", b, ARRAY_SIZE);

    printf("Computing A * B...\n\n");
    multiply_bignum(a, b, result);

    // ---- RAW DUMP: EXACTLY matches your simulator RES[] ----
    printf("Raw result in limb order (LSW → MSW):\n");
    for (int i = 0; i < ARRAY_SIZE * 2; i++) {
        printf("result[%d] = 0x%016" PRIx64 "\n", i, result[i]);
    }
    printf("\n");

    print_bignum("Result", result, ARRAY_SIZE * 2);

    printf("Writing numbers to bignum_data.s...\n");
    write_assembly_file(a, b);
    printf("Done!\n");

    printf("\nActual bit usage:\n");
    printf("A: %d bits\n", count_bits(a, ARRAY_SIZE));
    printf("B: %d bits\n", count_bits(b, ARRAY_SIZE));
    printf("Result: %d bits\n", count_bits(result, ARRAY_SIZE * 2));

    return 0;
}
