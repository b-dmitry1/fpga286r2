#ifndef BOARD_H
#define BOARD_H

#define SRAM_AREA       0x00000000u
#define UART_AREA       0x10000000u
#define TIMER_AREA      0x11000000u
#define GPIO_AREA       0x13000000u
#define USB_AREA        0x14000000u

#define USB1_AREA       0x14000000u
#define USB2_AREA       0x14001000u

extern unsigned char *sram;
extern volatile unsigned int  *gpio;
extern volatile unsigned int  *uart;
extern volatile unsigned int  *timer;

unsigned int time_us(void);

void print(const char *s);

#endif
