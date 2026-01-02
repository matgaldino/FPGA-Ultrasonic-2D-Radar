#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"
#include "alt_types.h"
#include "unistd.h"

/* 7-seg LUT (active-high segments).
 * DP is bit7 and is kept OFF (0).
 * Note: the VHDL inverts the outputs (HEXx <= not ...), so we write the normal pattern here.
 */
static const uint8_t SEG7_LUT[10] = {
    0x3F, /* 0 */
    0x06, /* 1 */
    0x5B, /* 2 */
    0x4F, /* 3 */
    0x66, /* 4 */
    0x6D, /* 5 */
    0x7D, /* 6 */
    0x07, /* 7 */
    0x7F, /* 8 */
    0x6F  /* 9 */
};

static inline uint8_t seg7(uint8_t digit)
{
    return (digit < 10) ? SEG7_LUT[digit] : 0x00;
}

int main(void)
{
    printf("\n========================================\n");
    printf("   ULTRASONIC TELEMETRE - NIOS II\n");
    printf("   (real distance = raw / 2)\n");
    printf("========================================\n\n");

    while (1)
    {
        /* 1) Read the Avalon peripheral (LSBs contain the distance code). */
        const uint32_t raw_value = IORD_32DIRECT(TELEMETRE_0_BASE, 0);
        const uint32_t dist_raw  = raw_value & 0x3FFu;

        /* 2) Apply scaling if your system returns a doubled value. */
        uint32_t distance_cm = dist_raw / 2u;

        /* 3) Clamp to 0..999 for display formatting. */
        if (distance_cm > 999u) {
            distance_cm = 999u;
        }

        /* 4) Split into decimal digits. */
        const uint8_t u = (uint8_t)( distance_cm        % 10u);
        const uint8_t t = (uint8_t)((distance_cm / 10u) % 10u);
        const uint8_t h = (uint8_t)((distance_cm / 100u) % 10u);

        /* 5) Pack HEX0..HEX2 into the lower 24 bits of HEX3_HEX0. */
        const uint32_t hex_low =
            ((uint32_t)seg7(u) << 0)  |
            ((uint32_t)seg7(t) << 8)  |
            ((uint32_t)seg7(h) << 16);

        IOWR_32DIRECT(HEX3_HEX0_BASE, 0, hex_low);

        /* 6) Optional UART debug. */
        printf("raw=%lu  ->  distance=%lu cm\n",
               (unsigned long)dist_raw,
               (unsigned long)distance_cm);

        usleep(60000); /* 60 ms */
    }

    return 0;
}
