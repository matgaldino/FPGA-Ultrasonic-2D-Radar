#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"
#include "unistd.h"

static const uint8_t SEG7_LUT[10] = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66,
    0x6D, 0x7D, 0x07, 0x7F, 0x6F
};

static inline uint8_t seg7(uint8_t digit)
{
    return (digit < 10u) ? SEG7_LUT[digit] : 0x00u;
}

static inline void split3(uint32_t v, uint8_t *h, uint8_t *t, uint8_t *u)
{
    if (v > 999u) v = 999u;
    *u = (uint8_t)(v % 10u);
    *t = (uint8_t)((v / 10u) % 10u);
    *h = (uint8_t)((v / 100u) % 10u);
}

static inline uint32_t angle_from_pos(uint32_t pos10b)
{
    if (pos10b > 1023u) pos10b = 1023u;
    return (pos10b * 180u) / 1023u;
}

static inline uint32_t pos_from_angle(uint32_t angle_deg)
{
    if (angle_deg > 180u) angle_deg = 180u;
    return (angle_deg * 1023u) / 180u;
}

int main(void)
{
    printf("\n========================================\n");
    printf("  ETAPE 3 - AFFICHAGE DES OBSTACLES\n");
    printf("  Sweep 0<->180 deg + Telemetre (cm)\n");
    printf("  HEX2..0 = angle, HEX5..3 = distance\n");
    printf("========================================\n\n");

    const uint32_t step_deg = 1u;

    uint32_t angle = 0u;
    int dir = +1;

    while (1)
    {
        const uint32_t pos = pos_from_angle(angle);

        IOWR_32DIRECT(SERVOMOTEUR_0_BASE, 0, pos);

        usleep(60000);

        const uint32_t raw = IORD_32DIRECT(TELEMETRE_0_BASE, 0);
        const uint32_t dist_cm = raw & 0x3FFu;

        printf("%lu° -> %lu cm\n",
               (unsigned long)angle,
               (unsigned long)dist_cm);

        uint8_t ah, at, au;
        uint8_t dh, dt, du;

        split3(angle,   &ah, &at, &au);
        split3(dist_cm, &dh, &dt, &du);

        const uint32_t hex3_hex0 =
            ((uint32_t)seg7(au) << 0)  |
            ((uint32_t)seg7(at) << 8)  |
            ((uint32_t)seg7(ah) << 16) |
            ((uint32_t)seg7(du) << 24);

        const uint32_t hex5_hex4 =
            ((uint32_t)seg7(dt) << 0)  |
            ((uint32_t)seg7(dh) << 8);

        IOWR_32DIRECT(HEX3_HEX0_BASE, 0, hex3_hex0);
        IOWR_32DIRECT(HEX5_HEX4_BASE, 0, hex5_hex4);

        if (dir > 0) {
            if (angle + step_deg >= 180u) {
                angle = 180u;
                dir = -1;
            } else {
                angle += step_deg;
            }
        } else {
            if (angle <= step_deg) {
                angle = 0u;
                dir = +1;
            } else {
                angle -= step_deg;
            }
        }
    }

    return 0;
}
