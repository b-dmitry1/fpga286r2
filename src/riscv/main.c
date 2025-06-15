#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "board.h"

#define NUM_PORTS          2
#define NUM_INTERFACES     2

#define CTRL1_CONNECTED    (1 << 16)
#define CTRL1_FULL_SPEED   (1 << 17)
#define CTRL1_FORCE_RESET  (1 << 18)
#define CTRL1_TX_ENABLE    (1 << 19)
#define CTRL1_IDLE         (1 << 20)
#define CTRL1_ODD_FRAME    (1 << 21)
#define CTRL1_FRAME_END    (1 << 22)

#define TOKEN_OUT	0xE1
#define TOKEN_IN	0x69
#define TOKEN_SETUP	0x2D

#define USB_NONE	0
#define USB_KEYBOARD	1
#define USB_MOUSE	2
#define USB_JOYSTICK	3
#define USB_STORAGE	8
#define USB_UNKNOWN	100

#define KEY_CTRL	1
#define KEY_SHIFT	2
#define KEY_ALT		4
#define KEY_CTRLR	0x10
#define KEY_SHIFTR	0x20
#define KEY_ALTR	0x40

#define MOUSE_LEFT	1
#define MOUSE_RIGHT	2
#define MOUSE_MIDDLE	4

volatile unsigned char* ps2_keyb = (volatile unsigned char*)0x15000000;

typedef enum
{
	s_nodevice, s_descr1, s_descr2, s_descr3, s_descr4,
	s_addr1, s_addr2, s_conf1, s_conf2, s_get_protocol,
	s_set_protocol, s_unstall, s_ready
} state_t;

typedef struct
{
	unsigned char bLength;
	unsigned char bDescriptorType;
	unsigned char bcdUSB[2];
	unsigned char bDeviceClass;
	unsigned char bDeviceSubClass;
	unsigned char bDeviceProtocol;
	unsigned char bMaxPacketSize0;
	unsigned char idVendor[2];
	unsigned char idProduct[2];
	unsigned char bcdDevice[2];
	unsigned char iManufacturer;
	unsigned char iProduct;
	unsigned char iSerialNumber;
	unsigned char bNumConfigurations;
} __attribute__((packed)) device_descr_t;

typedef struct
{
	struct
	{
		unsigned char bLength;
		unsigned char bDescriptorType;
		unsigned char wTotalLength[2];
		unsigned char bNumInterfaces;
		unsigned char bConfigurationValue;
		unsigned char iConfiguration;
		unsigned char bmAttributes;
		unsigned char bMaxPower;
	} conf;
	struct
	{
		unsigned char bLength;
		unsigned char bDescriptorType;
		unsigned char bInterfaceNumber;
		unsigned char bAlternateSetting;
		unsigned char bNumEndpoints;
		unsigned char bInterfaceClass;
		unsigned char bInterfaceSubClass;
		unsigned char bInterfaceProtocol;
		unsigned char iInterface;
	} intf;
} __attribute__((packed)) conf_descr_t;

const unsigned char setup0[] = { 0x80, 0x2D, 0x00, 0x10 };
const unsigned char setup0_set_address[] = { 0x80, 0x2D, 0x00, 0x10, 0x80, 0xC3, 0x00, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00 };
const unsigned char setup1[] = { 0x80, 0x2D, 0x01, 0xE8 };
const unsigned char setup1_set_conf[] = { 0x80, 0x2D, 0x01, 0xE8, 0x80, 0xC3, 0x00, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00 };
const unsigned char read0[] = { 0x80, 0x69, 0x00, 0x10 };
const unsigned char read01[] = { 0x80, 0x69, 0x80, 0xA0 };
const unsigned char read10[] = { 0x80, 0x69, 0x01, 0xE8 };
const unsigned char read1[] = { 0x80, 0x69, 0x81, 0x58 };
const unsigned char setup0_get_descr[] = { 0x80, 0x2D, 0x00, 0x10, 0x80, 0xC3, 0x80, 0x06, 0x00, 0x01, 0x00, 0x00, 0x12, 0x00 };
const unsigned char get_descr[] = { 0x80, 0x06, 0x00, 0x01, 0x00, 0x00, 0x12, 0x00 };
const unsigned char get_descr2[] = { 0x80, 0x06, 0x00, 0x02, 0x00, 0x00, 18, 0x00 };
unsigned char get_descr3[] = { 0x80, 0x06, 0x00, 0x03, 0x00, 0x00, 0x12, 0x00 };
unsigned char get_interface[] = { 0x81, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00 };
unsigned char set_interface[] = { 0x01, 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
const unsigned char get_protocol[] = { 0xA1, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00 };
const unsigned char setup1_set_protocol[] = { 0x80, 0x2D, 0x01, 0xE8, 0x80, 0xC3, 0x21, 0x0B, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 };
const unsigned char unstall[] = { 0x02, 0x01, 0x00, 0x00, 0x81, 0x00, 0x00, 0x00 };

unsigned char usb_buffer[80];
unsigned char str_buffer[64];

typedef struct {
	volatile unsigned char* ram;
	volatile unsigned int* ctrl1;
	volatile unsigned int* ctrl2;
	state_t state;
	int device_type;
	int current_interface;
	device_descr_t device_descr;
	conf_descr_t conf_descr;
	int errors;
	unsigned char no_protocol_setup_vid_pid[4];
	int print_packets;
	unsigned char keys[4];
	unsigned char ctrl;
} usb_t;

usb_t usb_ports[NUM_PORTS];

usb_t* usb = usb_ports;

const unsigned char xt_keys[] = {
	0, 0, 0, 0, 0x1E, 0x30, 0x2E, 0x20, 0x12, 0x21, 0x22, 0x23, 0x17, 0x24, 0x25, 0x26,
	0x32, 0x31, 0x18, 0x19, 0x10, 0x13, 0x1F, 0x14, 0x16, 0x2F, 0x11, 0x2D, 0x15, 0x2C, 0x02, 0x03,
	0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x1C, 0x01, 0x0E, 0x0F, 0x39, 0x0C, 0x0D, 0x1A,
	0x1B, 0x2B, 0, 0x27, 0x28, 0x29, 0x33, 0x34, 0x35, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40,
	0x41, 0x42, 0x43, 0x44, 0x57, 0x58, 0, 0x46, 0, 0x52, 0x47, 0x49, 0x53, 0x4F, 0x51, 0x4D,
	0x4B, 0x50, 0x48, 0x45, 0x35, 0x37, 0x4A, 0x4E, 0x1C, 0x4F, 0x50, 0x51, 0x4B, 0x4C, 0x4D, 0x47,
	0x48, 0x49, 0x52, 0x53
};

const unsigned char ascii_normal[] = {
	0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8, 9,
	'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0,
	'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '~', 0, '\\',
	'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
};

int recvchar(void);

void wait(void)
{
	volatile int w;
	for (w = 0; w < 1000; w++);
}

void wait0(void)
{
	volatile int w;
	for (w = 0; w < 30; w++);
}

int token_data(int addr, int ep)
{
	unsigned short b = 0x1F;
	int i;
	unsigned short a = addr + (ep << 7);
	unsigned short d = a;
	
	for (i = 0; i <= 10; i++)
	{
		if ((d ^ b) & 1)
		{
			b >>= 1;
			b ^= 0x14;
		}
		else
			b >>= 1;
		d >>= 1;
	}
	
	b ^= 0x1F;
	
	return a + (b << 11);
}

void init_token(int pid, int addr, int ep, unsigned char* buf)
{
	unsigned short data;
	
	data = token_data(addr, ep);
	
	buf[0] = 0x80;
	buf[1] = pid;
	buf[2] = data & 0xFF;
	buf[3] = data >> 8;
}

unsigned short crc16(const unsigned char *data, int count)
{
	int i, j;
	unsigned short crc = 0xFFFFu;
	
	for (i = 0; i < count; i++)
	{
		crc ^= data[i];
		
		for (j = 0; j < 8; j++)
		{
			if (crc & 0x0001)
				crc = (crc >> 1) ^ 0xA001;
			else
				crc = crc >> 1;
		}
	}
	
	return crc ^ 0xFFFFu;
}

int usb_send(const unsigned char* tx, int txsize, unsigned char* rx, int rxsize)
{
	int i, res = 0;
	unsigned int data, word;
	volatile int timeout;
	unsigned short crc;

	// Reset pointers
	*usb->ctrl2 = 0;

	// Fill tx queue
	if (txsize > 4)
	{
		crc = crc16(&tx[6], txsize - 6);
		for (i = 0; i < txsize; i++)
			usb->ram[i] = tx[i];

		usb->ram[i++] = (crc & 0xFF);
		usb->ram[i++] = (crc >> 8);
	}
	else
	{
		for (i = 0; i < txsize; i++)
			usb->ram[i] = tx[i];
	}

	// Set transmit end address
	*usb->ctrl2 = i << 8;

	// Wait for a safe time slot
	for (timeout = 0; timeout < 500; timeout++)
		if ((*usb->ctrl1 & (CTRL1_CONNECTED | CTRL1_IDLE | CTRL1_FRAME_END)) ==
			(CTRL1_CONNECTED | CTRL1_IDLE))
			break;

	// Transmit now 
	*usb->ctrl1 = CTRL1_TX_ENABLE;

	// exit if ACK or no response is required
	if (txsize == 2 || rx == NULL || rxsize < 2)
		return 0;

	// Wait for response
	/*
	for (timeout = 0; ; timeout++)
	{
		data = usb_ctrl[1];
		if ((data & (USB_RX_EMPTY | USB_IDLE)) == USB_IDLE)
			break;
		if (timeout == 500)
			return 0;
	}
	*/

	wait();

	for (timeout = 0; timeout < 500; timeout++)
	{
		word = *usb->ctrl1;
		if (!(word & CTRL1_CONNECTED))
			return 0;

		word = *usb->ctrl2 >> 24u;
		if (res >= (word & 0xFF))
			return res;

		rx[res] = usb->ram[res];
		res++;
		if (res >= rxsize)
			return res;
	}

	return 0;
}

int usb_read_multi(int addr, int ep, const unsigned char* setup, int setup_size, unsigned char* buffer, int read_bytes)
{
	int i, ofs, n, first;

	for (i = 0; i < 3; i++)
	{
		// Create and transmit SETUP packet
		init_token(TOKEN_SETUP, addr, ep, usb_buffer);
		usb_buffer[4] = 0x80;
		usb_buffer[5] = 0xC3;
		memcpy(&usb_buffer[6], setup, setup_size);
		n = usb_send(usb_buffer, 6 + setup_size, usb_buffer, 2);
		
		if (n > 0 && !memcmp(usb_buffer, "\x80\xD2", 2))
		{
			for (first = 1, ofs = 0; ofs < read_bytes || first; first = 0)
			{
				// Read next part
				init_token(TOKEN_IN, addr, ep, usb_buffer);
				n = usb_send(usb_buffer, 4, usb_buffer, sizeof(usb_buffer));
				while (n == 2 && usb_buffer[1] == 0x5A)
				{
					// Repeat a bit later if device is not ready
					wait0();
					init_token(TOKEN_IN, addr, ep, usb_buffer);
					n = usb_send(usb_buffer, 4, usb_buffer, sizeof(usb_buffer));
				}

				if (n == 2 && usb_buffer[1] == 0x1E)
					return -2;

				if (n < 4)
					break;
				if (!memcmp(usb_buffer, "\x80\x4B", 2) || !memcmp(usb_buffer, "\x80\xC3", 2))
				{
					memcpy(&buffer[ofs], &usb_buffer[2], n - 4);
					ofs += n - 4;
				}
				if (n == 4)
					break;
			}
			if (n > 4)
			{
				// Tell the device that we are done
				init_token(TOKEN_OUT, addr, ep, usb_buffer);
				usb_buffer[4] = 0x80;
				usb_buffer[5] = 0x4B;
				usb_send(usb_buffer, 6, usb_buffer, 2);
				return ofs;
			}
			return ofs + 2;
		}
	}
	return 0;
}

void int_to_str(int value, char* str)
{
	char buf[12];
	int i;

	if (value < 0)
	{
		value = -value;
		*str++ = '-';
	}

	for (i = 0; i < 10; i++)
	{
		buf[9 - i] = '0' + value % 10;
		value /= 10;
	}

	for (i = 0; i < 9 && buf[i] == '0'; i++);

	for (; i < 10; i++)
		*str++ = buf[i];

	*str = 0;
}

void print_int(int value)
{
	char s[16];
	int_to_str(value, s);
	print(s);
}

void print_hex(unsigned int value)
{
	const char *hex = "0123456789ABCDEF";
	int i;

	for (i = 0; i < 8; i++)
	{
		putchar(hex[value >> 28u]);
		value <<= 4;
	}
}

void print_hex16(unsigned int value)
{
	const char *hex = "0123456789ABCDEF";
	int i;

	for (i = 0; i < 4; i++)
	{
		putchar(hex[value >> 12u]);
		value <<= 4;
	}
}

void print_hex8(unsigned char value)
{
	const char *hex = "0123456789ABCDEF";

	putchar(hex[value >> 4]);
	putchar(hex[value & 0xF]);
}

void dump_packet(const unsigned char* packet, int size)
{
	int i;
	for (i = 0; i < size; i++)
		print_hex8(packet[i]);
}

void set_device_id(void)
{
	int device_class = usb->conf_descr.intf.bInterfaceClass ? usb->conf_descr.intf.bInterfaceClass : usb->device_descr.bDeviceClass;
	int device_subclass = usb->conf_descr.intf.bInterfaceSubClass ? usb->conf_descr.intf.bInterfaceSubClass : usb->device_descr.bDeviceSubClass;
	int protocol = usb->conf_descr.intf.bInterfaceProtocol ? usb->conf_descr.intf.bInterfaceProtocol : usb->device_descr.bDeviceProtocol;

	usb->device_type = USB_UNKNOWN;

	switch (device_class)
	{
		case 3:
			switch (device_subclass)
			{
				case 1:
					switch (protocol)
					{
						case 0:
						case 1:
							usb->device_type = USB_KEYBOARD;
							break;
						case 2:
							usb->device_type = USB_MOUSE;
							break;
						case 3:
							usb->device_type = USB_JOYSTICK;
							break;
					}
					break;
			}
			break;
		case 8:
			usb->device_type = USB_STORAGE;
			break;
		default:
			switch (device_class)
			{
				case 1: print("audio"); break;
				case 2: print("comm"); break;
				case 6: print("scanner"); break;
				case 7: print("printer"); break;
				case 9: print("hub"); break;
				case 0xE0: print("wireless"); break;
			}
			print(" - not supported"); break;
			return;
	}

	switch (usb->device_type)
	{
		case USB_KEYBOARD: print("keyboard"); break;
		case USB_MOUSE: print("mouse"); break;
		case USB_JOYSTICK: print("joystick"); break;
		case USB_STORAGE: print("storage - not supported"); break;
		default:
			print("unknown ");
			print_hex8(device_class);
			print(":");
			print_hex8(device_subclass);
			break;
	}
}

void dump(const unsigned char *addr)
{
	int i;
	for (i = 0; i < 256; i++)
	{
		if (i % 16 == 0)
		{
			print_hex((int)&addr[i]);
			print("  ");
		}
		print_hex8(addr[i]);
		print(" ");
		if (i % 16 == 15)
			print("\n");
	}
}

void process_keyboard_report(unsigned char* data, int size)
{
	int i, j, cont, found, key, ones;
	unsigned char keys[4];

	if (usb->ctrl != data[0])
	{
		if ((usb->ctrl ^ data[0]) & (KEY_CTRL | KEY_CTRLR))
		{
			if (data[0] & (KEY_CTRL | KEY_CTRLR))
				*ps2_keyb = 0x1D;
			else
				*ps2_keyb = 0x9D;
		}
		if ((usb->ctrl ^ data[0]) & (KEY_SHIFT | KEY_SHIFTR))
		{
			if (data[0] & (KEY_SHIFT | KEY_SHIFTR))
				*ps2_keyb = 0x2A;
			else
				*ps2_keyb = 0xAA;
		}
		if ((usb->ctrl ^ data[0]) & (KEY_ALT | KEY_ALTR))
		{
			if (data[0] & (KEY_ALT | KEY_ALTR))
				*ps2_keyb = 0x38;
			else
				*ps2_keyb = 0xB8;
		}
	}
	usb->ctrl = data[0];

	// Read keys
	for (ones = 0, i = 0; i < 4; i++)
	{
		keys[i] = i + 2 < size ? data[i + 2] : 0;
		if (keys[i] == 1)
			ones++;
	}

	// Do not parse if error signal presents
	if (ones > 2)
		return;

	// Sort
	for (cont = 1; cont; )
	{
		for (cont = 0, i = 0; i < 3; i++)
		{
			if (keys[i] > keys[i + 1])
			{
				key = keys[i];
				keys[i] = keys[i + 1];
				keys[i + 1] = key;
				cont = 1;
			}
		}
	}

	// Check for presses
	for (i = 0; i < 4; i++)
	{
		if (keys[i] == 0)
			continue;
		for (key = keys[i], found = 0, j = 0; j < 4; j++)
		{
			if (usb->keys[j] == key)
			{
				found = 1;
				break;
			}
		}
		if (!found)
		{
			if (key < sizeof(xt_keys))
			{
				key = xt_keys[key];
				*ps2_keyb = key;
//				print_int(time_us());
//				print(" ");
//				putchar(ascii_normal[key]);
//				print("\n");
			}
		}
	}

	// Check for releases
	for (i = 0; i < 4; i++)
	{
		if (usb->keys[i] == 0)
			continue;
		for (key = usb->keys[i], found = 0, j = 0; j < 4; j++)
		{
			if (keys[j] == key)
			{
				found = 1;
				break;
			}
		}
		if (!found)
		{
			if (key < sizeof(xt_keys))
			{
				key = xt_keys[key];
				*ps2_keyb = key | 0x80;
			}
		}
	}

	// Save current state
	for (i = 0; i < 4; i++)
		usb->keys[i] = keys[i];
}

void process_mouse_report(unsigned char* data, int size)
{

}

void process_joystick_report(unsigned char* data, int size)
{

}

void process_hid_report(unsigned char* data, int size)
{
	if (usb->device_type == USB_KEYBOARD ||
		(usb->conf_descr.conf.bNumInterfaces == 2 && usb->current_interface == 0))
		process_keyboard_report(data, size);
	else if (usb->device_type == USB_MOUSE ||
		(usb->conf_descr.conf.bNumInterfaces == 2 && usb->current_interface == 1))
		process_mouse_report(data, size);
	else if (usb->device_type == USB_JOYSTICK)
		process_joystick_report(data, size);
}

int main(void)
{
	char s[32];
	int i, n, size;
	unsigned int data, prev_data = 0;
	int usb_time = 0;
	int ch;

	print("\n\nHello from RISC-V!\n");

	memset(usb_ports, 0, sizeof(usb_ports));

	usb_ports[0].ram = usb1_ram;
	usb_ports[0].ctrl1 = usb1_ctrl1;
	usb_ports[0].ctrl2 = usb1_ctrl2;

	usb_ports[1].ram = usb2_ram;
	usb_ports[1].ctrl1 = usb2_ctrl1;
	usb_ports[1].ctrl2 = usb2_ctrl2;

	for (;;)
	{
		ch = recvchar();
		if (ch != 0)
			putchar(ch);

		data = *usb->ctrl1;

		if (!(data & CTRL1_CONNECTED))
		{
			if (prev_data & CTRL1_CONNECTED)
				print("USB device disconnected\n");
			usb->state = s_nodevice;
			usb->errors = 0;
		}

		if (usb->errors > 100)
		{
			print("Too many errors, resetting\n");
			*usb->ctrl1 = CTRL1_FORCE_RESET;
			usb->state = s_nodevice;
			usb->errors = 0;
		}

		if (((data ^ prev_data) & CTRL1_ODD_FRAME) && (!(data & CTRL1_FRAME_END)))
		{
			usb_time++;

			switch (usb->state)
			{
				case s_nodevice:
					usb->device_type = USB_NONE;
					if (data & CTRL1_CONNECTED)
					{
						if (data & CTRL1_FULL_SPEED)
							print("USB full-speed device connected\n");
						else
							print("USB low-speed device connected\n");
						usb->state = s_descr1;
					}
					usb->errors = 0;
					break;
				case s_descr1:
					n = usb_read_multi(0, 0, get_descr, sizeof(get_descr), (unsigned char*)&usb->device_descr, sizeof(usb->device_descr));
					if (n == sizeof(usb->device_descr))
					{
						print("VID: ");
						print_hex8(usb->device_descr.idVendor[1]);
						print_hex8(usb->device_descr.idVendor[0]);
						print(" PID: ");
						print_hex8(usb->device_descr.idProduct[1]);
						print_hex8(usb->device_descr.idProduct[0]);
						print("\n");
						usb->state = s_descr2;
					}
					break;
				case s_descr2:
					n = usb_read_multi(0, 0, get_descr2, sizeof(get_descr2), (unsigned char*)&usb->conf_descr, sizeof(usb->conf_descr));
					if (n == sizeof(usb->conf_descr))
					{
						print("Device type: ");
						set_device_id();
						print("\nInterfaces: ");
						print_int(usb->conf_descr.conf.bNumInterfaces);
						print(", configurations: ");
						print_int(usb->device_descr.bNumConfigurations);
						print("\n");
						usb->state = s_descr3;
					}
					break;
				case s_descr3:
					if (usb->device_descr.iManufacturer == 0)
					{
						usb->state = s_descr4;
						break;
					}
					get_descr3[2] = usb->device_descr.iManufacturer;
					n = usb_read_multi(0, 0, get_descr3, sizeof(get_descr3), str_buffer, 8);
					size = str_buffer[0];
					get_descr3[6] = size;
					if (n < 2 || size < 2 || size > 64)
					{
						print("Unable to identify\n");
						usb->state = s_descr4;
						break;
					}
					n = usb_read_multi(0, 0, get_descr3, sizeof(get_descr3), str_buffer, size - 2);
					if (n > 0)
					{
						for (i = 2; i < size; i += 2)
						{
							putchar(str_buffer[i]);
						}
						print(" ");
						usb->state = s_descr4;
					}
					break;
				case s_descr4:
					if (usb->device_descr.iProduct == 0)
					{
						usb->state = s_addr1;
						break;
					}
					get_descr3[2] = usb->device_descr.iProduct;
					n = usb_read_multi(0, 0, get_descr3, sizeof(get_descr3), str_buffer, 8);
					size = str_buffer[0];
					get_descr3[6] = size;
					if (n < 2 || size < 2 || size > 64)
					{
						print("Unable to identify\n");
						usb->state = s_addr1;
						break;
					}
					n = usb_read_multi(0, 0, get_descr3, sizeof(get_descr3), str_buffer, size);
					if (n > 0)
					{
						for (i = 2; i < size; i += 2)
						{
							putchar(str_buffer[i]);
						}
						print("\n");
						usb->state = s_addr1;
					}
					break;
				case s_addr1:
					n = usb_send(setup0_set_address, sizeof(setup0_set_address), usb_buffer, 2);
					if (n == 2 && !memcmp(usb_buffer, "\x80\xD2", 2))
					{
						usb->state = s_addr2;
						usb->errors = 0;
					}
					else
						usb->errors++;
					break;
				case s_addr2:
					n = usb_send(read0, sizeof(read0), usb_buffer, 4);
					if (n > 2 && (!memcmp(usb_buffer, "\x80\x4B", 2) || !memcmp(usb_buffer, "\x80\xC3", 2)))
					{
						usb->state = s_conf1;
						usb->errors = 0;
						print("Address ok\n");
					}
					else
						usb->errors++;
					break;
				case s_conf1:
					n = usb_send(setup1_set_conf, sizeof(setup1_set_conf), usb_buffer, sizeof(usb_buffer));
					if (n > 0)
					{
						if (!memcmp(usb_buffer, "\x80\xD2", 2))
						{
							// Bypass boot protocol setup if it was failed last time
							usb->state = memcmp(usb->no_protocol_setup_vid_pid, &usb->device_descr.idVendor, 4) ?
								s_get_protocol : s_ready;
							usb->errors = 0;
							print("Configuration ok\n");
							// dump_packet(&usb->device_descr, 36);
						}
					}
					else
						usb->errors++;
					break;
				case s_get_protocol:
					n = usb_read_multi(1, 0, get_protocol, sizeof(get_protocol), str_buffer, 1);
					if (n < 0)
					{
						// Oops. Save VID/PID and try again
						print("Stall on a protocol setup - resetting\n");
						memcpy(usb->no_protocol_setup_vid_pid, &usb->device_descr.idVendor, 4);
						*usb->ctrl1 = CTRL1_FORCE_RESET;
						usb->state = s_nodevice;
						usb->errors = 0;
					}
					if (n > 0)
					{
						usb->state = s_set_protocol;
					}
					break;
				case s_set_protocol:
					// Select BOOT protocol
					// We don't have resources to parse full reports
					n = usb_send(setup1_set_protocol, sizeof(setup1_set_protocol), usb_buffer, sizeof(usb_buffer));
					if (n > 0)
					{
						if (!memcmp(usb_buffer, "\x80\xD2", 2))
						{
							usb->state = s_ready;
							usb->errors = 0;
							print("Protocol ok\n");
						}
					}
					else
						usb->errors++;
					break;
				case s_unstall:
					init_token(TOKEN_SETUP, 1, 1, usb_buffer);
					usb_buffer[4] = 0x80;
					usb_buffer[5] = 0xC3;
					memcpy(&usb_buffer[6], unstall, sizeof(unstall));
					n = usb_send(usb_buffer, 6 + sizeof(unstall), usb_buffer, 2);
					if (n > 0)
					{
						if (!memcmp(usb_buffer, "\x80\xD2", 2))
						{
							usb->state = s_ready;
							usb->errors = 0;
							print("Unstall ok\n");
						}
					}
					else
						usb->errors++;
					break;
				case s_ready:
					init_token(TOKEN_IN, 1, 1 + usb->current_interface, usb_buffer);
					n = usb_send(usb_buffer, 4, usb_buffer, sizeof(usb_buffer));
					if (n > 0)
					{
						if (usb->conf_descr.conf.bNumInterfaces > 1)
							usb->current_interface = (usb->current_interface + 1) % NUM_INTERFACES;
						usb->errors = 0;
						if (n > 2)
						{
							if (!memcmp(usb_buffer, "\x80\x4B", 2) || !memcmp(usb_buffer, "\x80\xC3", 2))
							{
								if (n > 4)
								{
									process_hid_report(&usb_buffer[2], n - 4);
									if (usb->print_packets)
									{
										dump_packet(usb_buffer, n);
										print("\n");
									}
								}
							}
						}
					}
					else
						usb->errors++;
					break;
			}
		}

		prev_data = data;
	}
}
