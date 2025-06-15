#include "board.h"

unsigned char *sram              = (unsigned char *)SRAM_AREA;

volatile unsigned int  *gpio     = (volatile unsigned int  *)GPIO_AREA;
volatile unsigned int  *uart     = (volatile unsigned int  *)UART_AREA;
volatile unsigned int  *timer    = (volatile unsigned int  *)TIMER_AREA;

volatile unsigned char* usb1_ram = (volatile unsigned char*)USB1_AREA;
volatile unsigned int* usb1_ctrl1 = (volatile unsigned int*)(USB1_AREA + 0x200);
volatile unsigned int* usb1_ctrl2 = (volatile unsigned int*)(USB1_AREA + 0x204);

volatile unsigned char* usb2_ram = (volatile unsigned char*)USB2_AREA;
volatile unsigned int* usb2_ctrl1 = (volatile unsigned int*)(USB2_AREA + 0x200);
volatile unsigned int* usb2_ctrl2 = (volatile unsigned int*)(USB2_AREA + 0x204);

unsigned int time_us(void)
{
	return timer[0xBFF8 >> 2];
}
