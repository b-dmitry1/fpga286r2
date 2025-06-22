#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include "config.h"
#include "board.h"

#define UART_TX_EMPTY		0x4000
#define UART_RX_NOT_EMPTY	0x100

// Heap and stack
static char* _cur_brk = 0;

void sendchar(int ch)
{
	while (!(uart[1] & UART_TX_EMPTY));
	*uart = ch;
}

int recvchar(void)
{
	if (uart[1] & UART_RX_NOT_EMPTY)
		return *uart & 0xFF;
	return 0;
}

int putchar(int ch)
{
	if (ch == '\n')
		sendchar('\r');
	sendchar(ch);
}

void print(const char *s)
{
	while (*s) putchar(*s++);
}

int _read_r(struct _reent* r, int file, char* ptr, int len)
{
	int i, ch;

	for (i = 0; i < len; i++)
	{
		ch = recvchar();
		if (ch < 0) break;
		if (ch == '\r') ch = '\n';
		sendchar(ch);
		ptr[i] = (char)ch;
	}

	return i;
}

int _write_r(struct _reent* r, int file, char* ptr, int len)
{
	int i;

	for (i = 0; i < len; i++)
	{
		if (ptr[i] == '\n')
		{
			sendchar('\r');
		}
		sendchar(ptr[i]);
	}

	return len;
}

int _lseek_r(struct _reent* r, int file, int ptr, int dir)
{
	return 0;
}

int _close_r(struct _reent* r, int file)
{
	return -1;
}

caddr_t _sbrk_r(struct _reent* r, int incr)
{
	errno = ENOMEM;
	return (void *)-1;
}

int _fstat_r(struct _reent* r, int file, struct stat* st)
{
	st->st_mode = S_IFCHR;
	return 0;
}

int _isatty_r(struct _reent* r, int fd)
{
	return 1;
}

void _exit(int rc)
{
	for (;;);
}

int _kill(int pid, int sig)
{
	errno = EINVAL;
	return -1;
}

int _getpid(void)
{
	return 1;
}
