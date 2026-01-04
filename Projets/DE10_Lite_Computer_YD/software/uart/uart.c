#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include "system.h"
#include "io.h"

/* Offsets (SPAN=16 => 0x0,0x4,0x8,0xC) */
#define UART_DATA_OFFSET    0x00
#define UART_STATUS_OFFSET  0x04

/* Bits do status/controle (conforme nosso TB) */
#define UART_RX_VALID   (1u << 0)  /* status: tem dado recebido */
#define UART_TX_BUSY    (1u << 1)  /* status: transmissor ocupado */
#define UART_RX_ACK     (1u << 0)  /* write no STATUS: limpa rx_valid */

static inline uint32_t uart_status(void)
{
    return IORD_32DIRECT(UART_0_BASE, UART_STATUS_OFFSET);
}

static void uart_putchar(char c)
{
    while (uart_status() & UART_TX_BUSY) {
        /* wait */
    }
    IOWR_32DIRECT(UART_0_BASE, UART_DATA_OFFSET, (uint32_t)(uint8_t)c);
}

static char uart_getchar_blocking(void)
{
    while ((uart_status() & UART_RX_VALID) == 0u) {
        /* wait */
    }

    char c = (char)(IORD_32DIRECT(UART_0_BASE, UART_DATA_OFFSET) & 0xFFu);

    /* ACK para limpar RX_VALID */
    IOWR_32DIRECT(UART_0_BASE, UART_STATUS_OFFSET, UART_RX_ACK);

    return c;
}

static void uart_puts(const char *s)
{
    while (*s) uart_putchar(*s++);
}

int main(void)
{
    uart_puts("\r\nUART Avalon (uart_0) OK\r\n");
    uart_puts("Write something to echo:\r\n");

    while (1) {
        char c = uart_getchar_blocking();

        uart_putchar(c);           /* echo */

        if (c == '\r') {           /* conveniência */
            uart_putchar('\n');
        }
    }
}
