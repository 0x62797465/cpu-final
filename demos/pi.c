#include <stdint.h>
#define UART_TXDATA  (*(volatile unsigned char *)0x10000000u)
#define UART_STATUS  (*(volatile uint32_t *)0x10000008u)

static void putchar_uart(char c) {
    while ((UART_STATUS & 1u) == 0u) {
    }
    UART_TXDATA = (unsigned char)c;
}
static void puts_uart(const char *s) {
    while (*s) {
        putchar_uart(*s++);
    }
}
unsigned __udivsi3(unsigned n, unsigned d)
{
    unsigned q = 0;
    unsigned r = 0;

    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1);

        if (r >= d) {
            r -= d;
            q |= 1u << i;
        }
    }

    return q;
}
unsigned __umodsi3(unsigned n, unsigned d)
{
    unsigned r = 0;

    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1);

        if (r >= d)
            r -= d;
    }

    return r;
}
int __divsi3(int a, int b)
{
    int sign_a = a < 0 ? -1 : 0;
    int sign_b = b < 0 ? -1 : 0;

    unsigned ua = (a ^ sign_a) - sign_a; // abs(a)
    unsigned ub = (b ^ sign_b) - sign_b; // abs(b)

    int sign = sign_a ^ sign_b;

    unsigned q = __udivsi3(ua, ub);

    return (q ^ sign) - sign;
}
int __modsi3(int a, int b)
{

    return a - __divsi3(a, b) * b;
}
void *memset(void *dest, int c, unsigned int n)
{
    unsigned char *p = (unsigned char *)dest;

    while (n--) {
        *p++ = (unsigned char)c;
    }

    return dest;
}
int __mulsi3(int a, int b)
{
    unsigned ua = a;
    unsigned ub = b;
    unsigned r = 0;

    while (ub) {
        if (ub & 1)
            r += ua;
        ua <<= 1;
        ub >>= 1;
    }

    return r;
}
static void print4(int x)
{
    putchar_uart('0' + (x / 1000) % 10);
    putchar_uart('0' + (x / 100) % 10);
    putchar_uart('0' + (x / 10) % 10);
    putchar_uart('0' + x % 10);
}
int main() {
    int r[2800 + 1];
    int i, k;
    int b, d;
    int c = 0;

    for (i = 0; i < 2800; i++) {
	r[i] = 2000;
    }
    r[i] = 0;

    for (k = 2800; k > 0; k -= 14) {
	d = 0;

	i = k;
	for (;;) {
	    d += r[i] * 10000;
	    b = 2 * i - 1;

	    r[i] = d % b;
	    d /= b;
	    i--;
	    if (i == 0) break;
	    d *= i;
	}
	print4(c + d / 10000);
	c = d % 10000;
    }

    return 0;
}

