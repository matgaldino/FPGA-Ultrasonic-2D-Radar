#include <stdint.h>
#include <stdio.h>
#include <math.h>
#include "system.h"
#include "io.h"
#include "unistd.h"

#define PIXEL_BUF_CTRL_BASE VGA_SUBSYSTEM_VGA_PIXEL_DMA_BASE
#define RGB_RESAMPLER_BASE  VGA_SUBSYSTEM_VGA_PIXEL_RGB_RESAMPLER_BASE
#define CHAR_BUF_BASE       VGA_SUBSYSTEM_CHAR_BUF_SUBSYSTEM_ONCHIP_SRAM_BASE

#define SCREEN_W 320
#define SCREEN_H 240
#define PI 3.14159265358979323846

#define BLACK  0x0000
#define GREEN  0x07E0
#define RED    0xF800
#define BLUE   0x001F
#define WHITE  0xFFFF
#define GRAY   0x8410

#define UART_DATA_OFFSET    0x00
#define UART_STATUS_OFFSET  0x04
#define UART_RX_VALID       (1u << 0)
#define UART_TX_BUSY        (1u << 1)
#define UART_RX_ACK         (1u << 0)

static const uint8_t SEG7_LUT[10] = {
    0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F
};

static int res_offset, col_offset;
static int cx, cy, radar_r;

static uint32_t angle_min = 0;
static uint32_t angle_max = 180;
static uint32_t step_deg  = 2;
static uint32_t dist_max_cm = 75;

typedef enum { STATE_CMD = 0, STATE_RUN = 1 } radar_state_t;
static radar_state_t state = STATE_CMD;

static int stop_level_sw0 = 1;

static inline uint8_t seg7(uint8_t d) { return (d < 10u) ? SEG7_LUT[d] : 0u; }

static inline void split3(uint32_t v, uint8_t *h, uint8_t *t, uint8_t *u)
{
    if (v > 999u) v = 999u;
    *u = (uint8_t)(v % 10u);
    *t = (uint8_t)((v / 10u) % 10u);
    *h = (uint8_t)((v / 100u) % 10u);
}

static inline uint32_t clamp_u32(uint32_t v, uint32_t lo, uint32_t hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline uint32_t pos_from_angle(uint32_t a)
{
    a = clamp_u32(a, 0u, 180u);
    return (a * 1023u) / 180u;
}

static inline int cm_to_px(int cm)
{
    if (cm < 0) cm = 0;
    int m = (int)dist_max_cm;
    if (m < 1) m = 1;
    if (cm > m) cm = m;
    return (cm * radar_r) / m;
}

static inline uint32_t uart_status(void)
{
    return IORD_32DIRECT(UART_0_BASE, UART_STATUS_OFFSET);
}

static void uart_putchar(char c)
{
    while (uart_status() & UART_TX_BUSY) { }
    IOWR_32DIRECT(UART_0_BASE, UART_DATA_OFFSET, (uint32_t)(uint8_t)c);
}

static void uart_puts(const char *s)
{
    while (*s) uart_putchar(*s++);
}

static char uart_getchar_blocking(void)
{
    while ((uart_status() & UART_RX_VALID) == 0u) { }
    char c = (char)(IORD_32DIRECT(UART_0_BASE, UART_DATA_OFFSET) & 0xFFu);
    IOWR_32DIRECT(UART_0_BASE, UART_STATUS_OFFSET, UART_RX_ACK);
    return c;
}

static void uart_put_u32(uint32_t v)
{
    char buf[11];
    int i = 0;
    if (v == 0u) { uart_putchar('0'); return; }
    while (v && i < 10) {
        buf[i++] = (char)('0' + (v % 10u));
        v /= 10u;
    }
    while (i--) uart_putchar(buf[i]);
}

static int is_space(char c)
{
    return (c == ' ' || c == '\t' || c == '\r' || c == '\n');
}

static char up(char c)
{
    if (c >= 'a' && c <= 'z') return (char)(c - 'a' + 'A');
    return c;
}

static inline int sw0_level(void)
{
    uint32_t sw = IORD_32DIRECT(SLIDER_SWITCHES_BASE, 0);
    return ((sw & 0x1u) != 0u);
}

static void msg_init(void) { uart_puts("Radar ready. Use HELP.\r\n"); }
static void reply_ok(void) { uart_puts("OK\r\n"); }
static void reply_run(void) { uart_puts("RUN\r\n"); }
static void reply_stop(void) { uart_puts("STOP\r\n"); }
static void reply_err(void) { uart_puts("ERR\r\n"); }
static void reply_unknown(void) { uart_puts("UNKNOWN\r\n"); }

static void clear_char_buffer(void)
{
    volatile char *cb = (volatile char *)CHAR_BUF_BASE;
    for (int y = 0; y < 60; y++) {
        int off = (y << 7);
        for (int x = 0; x < 128; x++) cb[off + x] = ' ';
    }
}

static void video_box(int x1, int y1, int x2, int y2, uint16_t color)
{
    int base = *(volatile int *)PIXEL_BUF_CTRL_BASE;
    int xf = 1 << (res_offset + col_offset);
    int yf = 1 << res_offset;

    x1 /= xf; x2 /= xf;
    y1 /= yf; y2 /= yf;

    for (int row = y1; row <= y2; row++) {
        for (int col = x1; col <= x2; col++) {
            int ptr = base + (row << (10 - res_offset - col_offset)) + (col << 1);
            *(volatile uint16_t *)ptr = color;
        }
    }
}

static void plot(int x, int y, uint16_t c)
{
    if (x < 0 || x >= SCREEN_W || y < 0 || y >= SCREEN_H) return;

    int base = *(volatile int *)PIXEL_BUF_CTRL_BASE;
    int xf = 1 << (res_offset + col_offset);
    int yf = 1 << res_offset;

    x /= xf;
    y /= yf;

    int ptr = base + (y << (10 - res_offset - col_offset)) + (x << 1);
    *(volatile uint16_t *)ptr = c;
}

static void draw_line(int x0, int y0, int x1, int y1, uint16_t c)
{
    int dx = (x1 > x0) ? (x1 - x0) : (x0 - x1);
    int sx = (x0 < x1) ? 1 : -1;
    int dy = (y1 > y0) ? -(y1 - y0) : -(y0 - y1);
    int sy = (y0 < y1) ? 1 : -1;
    int err = dx + dy;

    for (;;) {
        plot(x0, y0, c);
        if (x0 == x1 && y0 == y1) break;
        int e2 = err << 1;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

static void draw_arc_cm(int cm, uint16_t c)
{
    int r = cm_to_px(cm);
    for (int a = 0; a <= 180; a += 2) {
        double rad = (double)a * PI / 180.0;
        int x = cx + (int)(cos(rad) * r);
        int y = cy - (int)(sin(rad) * r);
        plot(x, y, c);
    }
}

static void draw_static(void)
{
    video_box(0, 0, SCREEN_W - 1, SCREEN_H - 1, BLACK);
    clear_char_buffer();

    int m = (int)dist_max_cm;
    int a1 = (m * 1) / 4;
    int a2 = (m * 2) / 4;
    int a3 = (m * 3) / 4;
    if (a1 < 1) a1 = 1;

    draw_arc_cm(m, WHITE);
    draw_arc_cm(a3, GRAY);
    draw_arc_cm(a2, GRAY);
    draw_arc_cm(a1, GRAY);

    draw_line(0, cy, SCREEN_W - 1, cy, BLUE);
    draw_line(cx, 0, cx, SCREEN_H - 1, BLUE);
}

static void print_help(void)
{
    uart_puts("HELP\r\n");
    uart_puts("  HELP\r\n");
    uart_puts("  P\r\n");
    uart_puts("  R <min_deg> <max_deg>\r\n");
    uart_puts("  S <step_deg>\r\n");
    uart_puts("  D <max_cm>\r\n");
    uart_puts("  RUN\r\n");
    uart_puts("  (stop: toggle SW0)\r\n");
}

static void print_params(void)
{
    uart_puts("R ");
    uart_put_u32(angle_min);
    uart_putchar(' ');
    uart_put_u32(angle_max);
    uart_puts("  S ");
    uart_put_u32(step_deg);
    uart_puts("  D ");
    uart_put_u32(dist_max_cm);
    uart_puts("\r\n");
}

static void skip_spaces(char **pp)
{
    while (**pp && is_space(**pp)) (*pp)++;
}

static uint32_t parse_u32_adv(char **pp, int *ok)
{
    uint32_t v = 0;
    int any = 0;

    skip_spaces(pp);

    while (**pp >= '0' && **pp <= '9') {
        any = 1;
        v = (uint32_t)(v * 10u + (uint32_t)(**pp - '0'));
        (*pp)++;
    }

    *ok = any;
    return v;
}

static int is_run_cmd(const char *ln)
{
    const char *p = ln;
    while (*p && is_space(*p)) p++;
    if (up(p[0]) != 'R') return 0;
    if (up(p[1]) != 'U') return 0;
    if (up(p[2]) != 'N') return 0;
    if (p[3] != '\0' && !is_space(p[3])) return 0;
    return 1;
}

static int is_help_cmd(const char *ln)
{
    const char *p = ln;
    while (*p && is_space(*p)) p++;
    return (up(p[0]) == 'H' && up(p[1]) == 'E' && up(p[2]) == 'L' && up(p[3]) == 'P' &&
            (p[4] == '\0' || is_space(p[4])));
}

static int is_p_cmd(const char *ln)
{
    const char *p = ln;
    while (*p && is_space(*p)) p++;
    return (up(p[0]) == 'P' && (p[1] == '\0' || is_space(p[1])));
}

static void handle_cmd_line(char *ln)
{
    char *p = ln;
    while (*p && is_space(*p)) p++;
    if (*p == '\0') return;

    char cmd0 = up(*p);

    if (cmd0 == 'H') {
        if (is_help_cmd(p)) { print_help(); return; }
        reply_unknown();
        return;
    }

    if (cmd0 == 'P') {
        if (is_p_cmd(p)) { print_params(); return; }
        reply_unknown();
        return;
    }

    if (cmd0 == 'R') {
        p++;
        int ok1 = 0, ok2 = 0;
        uint32_t a = parse_u32_adv(&p, &ok1);
        uint32_t b = parse_u32_adv(&p, &ok2);
        if (!(ok1 && ok2)) { reply_err(); return; }
        a = clamp_u32(a, 0u, 180u);
        b = clamp_u32(b, 0u, 180u);
        if (a > b) { uint32_t t = a; a = b; b = t; }
        angle_min = a;
        angle_max = b;
        reply_ok();
        return;
    }

    if (cmd0 == 'S') {
        p++;
        int ok1 = 0;
        uint32_t s = parse_u32_adv(&p, &ok1);
        if (!ok1) { reply_err(); return; }
        step_deg = clamp_u32(s, 1u, 30u);
        reply_ok();
        return;
    }

    if (cmd0 == 'D') {
        p++;
        int ok1 = 0;
        uint32_t d = parse_u32_adv(&p, &ok1);
        if (!ok1) { reply_err(); return; }
        dist_max_cm = clamp_u32(d, 1u, 200u);
        draw_static();
        reply_ok();
        return;
    }

    reply_unknown();
}

static void cmd_wait_and_process(void)
{
    static char ln[64];
    int i = 0;

    for (;;) {
        char c = uart_getchar_blocking();

        if (c == '\r' || c == '\n') {
            ln[i] = '\0';

            if (is_run_cmd(ln)) {
                int start_level = sw0_level();
                stop_level_sw0 = start_level ? 0 : 1;
                draw_static();
                state = STATE_RUN;
                reply_run();
                return;
            }

            handle_cmd_line(ln);
            i = 0;
        } else {
            if (i < (int)sizeof(ln) - 1) ln[i++] = c;
        }
    }
}

static void init_hex_displays_zero(void)
{
    uint32_t z = seg7(0);
    IOWR_32DIRECT(HEX3_HEX0_BASE, 0,
        (z << 0) | (z << 8) | (z << 16) | (z << 24));
    IOWR_32DIRECT(HEX5_HEX4_BASE, 0,
        (z << 0) | (z << 8));
}

static void run_step(uint32_t *angle, int *dir)
{
    if (*angle < angle_min) *angle = angle_min;
    if (*angle > angle_max) *angle = angle_max;

    IOWR_32DIRECT(SERVOMOTEUR_0_BASE, 0, pos_from_angle(*angle));
    usleep(60000);

    uint32_t raw = IORD_32DIRECT(TELEMETRE_0_BASE, 0);
    uint32_t dist = raw & 0x3FFu;
    if (dist > dist_max_cm) dist = dist_max_cm;

    double rad = (double)(*angle) * PI / 180.0;
    int r_obj = cm_to_px((int)dist);

    int x_obj = cx + (int)(cos(rad) * r_obj);
    int y_obj = cy - (int)(sin(rad) * r_obj);
    int x_max = cx + (int)(cos(rad) * radar_r);
    int y_max = cy - (int)(sin(rad) * radar_r);

    draw_line(cx, cy, x_obj, y_obj, GREEN);
    draw_line(x_obj, y_obj, x_max, y_max, RED);

    uint8_t ah, at, au, dh, dt, du;
    split3(*angle, &ah, &at, &au);
    split3(dist,  &dh, &dt, &du);

    IOWR_32DIRECT(HEX3_HEX0_BASE, 0,
        ((uint32_t)seg7(au) << 0)  |
        ((uint32_t)seg7(at) << 8)  |
        ((uint32_t)seg7(ah) << 16) |
        ((uint32_t)seg7(du) << 24));

    IOWR_32DIRECT(HEX5_HEX4_BASE, 0,
        ((uint32_t)seg7(dt) << 0) |
        ((uint32_t)seg7(dh) << 8));

    if (*dir > 0) {
        if (*angle + step_deg >= angle_max) { *angle = angle_max; *dir = -1; }
        else *angle += step_deg;
    } else {
        if (*angle <= angle_min + step_deg) { *angle = angle_min; *dir = +1; }
        else *angle -= step_deg;
    }

    usleep(40000);
}

int main(void)
{
    volatile int *res = (int *)(PIXEL_BUF_CTRL_BASE + 8);
    int sx = (*res) & 0xFFFF;

    volatile int *rgb = (int *)(RGB_RESAMPLER_BASE);
    int db = (*rgb) & 0x3F;

    res_offset = (sx == 160) ? 1 : 0;
    col_offset = (db == 8) ? 1 : 0;

    cx = SCREEN_W / 2;
    cy = SCREEN_H - 10;
    radar_r = 200;

    draw_static();
    init_hex_displays_zero();
    msg_init();

    uint32_t angle = 0;
    int dir = +1;

    for (;;) {
        if (state == STATE_CMD) {
            cmd_wait_and_process();
            continue;
        }

        if (sw0_level() == stop_level_sw0) {
            state = STATE_CMD;
            reply_stop();
            init_hex_displays_zero();
            msg_init();
            continue;
        }

        run_step(&angle, &dir);
    }
}
