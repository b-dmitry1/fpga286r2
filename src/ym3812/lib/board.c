#include "board.h"

unsigned char *sram              = (unsigned char *)SRAM_AREA;

volatile unsigned int  *gpio     = (volatile unsigned int  *)GPIO_AREA;
volatile unsigned int  *uart     = (volatile unsigned int  *)UART_AREA;
volatile unsigned int  *timer    = (volatile unsigned int  *)TIMER_AREA;

unsigned int time_us(void)
{
	return timer[0xBFF8 >> 2];
}
