#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"
#include "unistd.h"
#include "alt_types.h"

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
    return (digit < 10u) ? SEG7_LUT[digit] : 0x00u;
}

static inline uint32_t angle_from_sw(uint32_t sw10b)
{
    if (sw10b > 1023u) sw10b = 1023u;
    return (sw10b * 180u) / 1023u;
}

int main(void)
{
    printf("\n========================================\n");
    printf("   SERVO IP (AVALON) - NIOS II CONTROL\n");
    printf("   SW[9:0] -> angle (0..180 deg)\n");
    printf("========================================\n\n");

    while (1)
    {
        const uint32_t sw_val = IORD_32DIRECT(SLIDER_SWITCHES_BASE, 0) & 0x3FFu;
        const uint32_t angle  = angle_from_sw(sw_val);

        IOWR_32DIRECT(SERVOMOTEUR_0_BASE, 0, sw_val);

        uint32_t angle_disp = angle;
        if (angle_disp > 999u) angle_disp = 999u;

        const uint8_t u = (uint8_t)( angle_disp        % 10u);
        const uint8_t t = (uint8_t)((angle_disp / 10u) % 10u);
        const uint8_t h = (uint8_t)((angle_disp / 100u) % 10u);

        const uint32_t hex_low =
            ((uint32_t)seg7(u) << 0)  |
            ((uint32_t)seg7(t) << 8)  |
            ((uint32_t)seg7(h) << 16);

        IOWR_32DIRECT(HEX3_HEX0_BASE, 0, hex_low);

        printf("SW=%lu  -> angle=%lu deg\n",
               (unsigned long)sw_val,
               (unsigned long)angle);

        usleep(50000);
    }

    return 0;
}
