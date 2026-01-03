#include <stdint.h>
#include <stdio.h>
#include <math.h>
#include "system.h"
#include "io.h"
#include "unistd.h"

/* ================= VGA ================= */

#define PIXEL_BUF_CTRL_BASE VGA_SUBSYSTEM_VGA_PIXEL_DMA_BASE
#define RGB_RESAMPLER_BASE  VGA_SUBSYSTEM_VGA_PIXEL_RGB_RESAMPLER_BASE
#define CHAR_BUF_BASE       VGA_SUBSYSTEM_CHAR_BUF_SUBSYSTEM_ONCHIP_SRAM_BASE

#define SCREEN_W 320
#define SCREEN_H 240
#define PI 3.14159265358979323846

/* ================= RADAR ================= */

#define RADAR_MAX_CM 100
#define STEP_DEG     3

/* ================= CORES RGB565 ================= */

#define BLACK  0x0000
#define GREEN  0x07E0
#define RED    0xF800
#define BLUE   0x001F
#define WHITE  0xFFFF
#define GRAY   0x8410

/* ================= 7 SEG ================= */

static const uint8_t SEG7_LUT[10] = {
    0x3F,0x06,0x5B,0x4F,0x66,
    0x6D,0x7D,0x07,0x7F,0x6F
};

static inline uint8_t seg7(uint8_t d) {
    return (d < 10) ? SEG7_LUT[d] : 0;
}

static inline void split3(uint32_t v, uint8_t *h, uint8_t *t, uint8_t *u)
{
    if (v > 999) v = 999;
    *u = v % 10;
    *t = (v / 10) % 10;
    *h = (v / 100) % 10;
}

/* ================= VGA VARS ================= */

static int res_offset, col_offset;
static int cx, cy, radar_r;

/* ================= UTIL ================= */

static inline uint32_t pos_from_angle(uint32_t a) {
    if (a > 180) a = 180;
    return (a * 1023) / 180;
}

static inline int cm_to_px(int cm) {
    if (cm > RADAR_MAX_CM) cm = RADAR_MAX_CM;
    return (cm * radar_r) / RADAR_MAX_CM;
}

/* ================= VGA PRIMITIVAS ================= */

static void plot(int x, int y, uint16_t c)
{
    if (x < 0 || x >= SCREEN_W || y < 0 || y >= SCREEN_H) return;

    int base = *(volatile int *)PIXEL_BUF_CTRL_BASE;
    int xf = 1 << (res_offset + col_offset);
    int yf = 1 << res_offset;

    x /= xf; y /= yf;

    int ptr = base + (y << (10 - res_offset - col_offset)) + (x << 1);
    *(volatile uint16_t *)ptr = c;
}

static void draw_line(int x0,int y0,int x1,int y1,uint16_t c)
{
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;

    while (1) {
        plot(x0,y0,c);
        if (x0==x1 && y0==y1) break;
        int e2 = 2*err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

static void draw_arc(int cm, uint16_t c)
{
    int r = cm_to_px(cm);
    for (int a=0;a<=180;a+=2) {
        double rad = a*PI/180.0;
        int x = cx + (int)(cos(rad)*r);  // 0° À DIREITA
        int y = cy - (int)(sin(rad)*r);
        plot(x,y,c);
    }
}

/* ================= MAIN ================= */

int main(void)
{
    volatile int *res = (int *)(PIXEL_BUF_CTRL_BASE + 8);
    int sx = (*res)&0xFFFF;

    volatile int *rgb = (int *)(RGB_RESAMPLER_BASE);
    int db = (*rgb)&0x3F;

    res_offset = (sx==160)?1:0;
    col_offset = (db==8)?1:0;

    cx = SCREEN_W/2;
    cy = SCREEN_H - 10;
    radar_r = 200;

    /* Limpa tela */
    for(int y=0;y<SCREEN_H;y++)
        for(int x=0;x<SCREEN_W;x++)
            plot(x,y,BLACK);

    /* Radar estático */
    draw_arc(100,WHITE);
    draw_arc(75,GRAY);
    draw_arc(50,GRAY);
    draw_arc(25,GRAY);
    draw_line(0,cy,SCREEN_W-1,cy,BLUE);
    draw_line(cx,0,cx,SCREEN_H-1,BLUE);

    uint32_t angle = 0;
    int dir = +1;

    while (1)
    {
        uint32_t sw = IORD_32DIRECT(SLIDER_SWITCHES_BASE,0);

        if ((sw & 0x1) == 0) {
            usleep(100000);
            continue;
        }

        IOWR_32DIRECT(SERVOMOTEUR_0_BASE,0,pos_from_angle(angle));
        usleep(60000);

        uint32_t raw = IORD_32DIRECT(TELEMETRE_0_BASE,0);
        uint32_t dist = raw & 0x3FF;

        if (dist > RADAR_MAX_CM) dist = RADAR_MAX_CM;

        double rad = angle*PI/180.0;
        int r_obj = cm_to_px(dist);

        int x_obj = cx + (int)(cos(rad)*r_obj);
        int y_obj = cy - (int)(sin(rad)*r_obj);
        int x_max = cx + (int)(cos(rad)*radar_r);
        int y_max = cy - (int)(sin(rad)*radar_r);

        draw_line(cx,cy,x_obj,y_obj,GREEN);
        draw_line(x_obj,y_obj,x_max,y_max,RED);

        printf("%lu° -> %lu cm\n",(unsigned long)angle,(unsigned long)dist);

        uint8_t ah,at,au,dh,dt,du;
        split3(angle,&ah,&at,&au);
        split3(dist,&dh,&dt,&du);

        IOWR_32DIRECT(HEX3_HEX0_BASE,0,
            seg7(au)|(seg7(at)<<8)|(seg7(ah)<<16)|(seg7(du)<<24));
        IOWR_32DIRECT(HEX5_HEX4_BASE,0,
            seg7(dt)|(seg7(dh)<<8));

        if (dir>0) {
            if (angle+STEP_DEG>=180){angle=180;dir=-1;}
            else angle+=STEP_DEG;
        } else {
            if (angle<=STEP_DEG){angle=0;dir=+1;}
            else angle-=STEP_DEG;
        }

        usleep(40000);
    }
}
