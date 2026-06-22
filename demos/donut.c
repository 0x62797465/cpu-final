#include <stdint.h>

#define R(mul,shift,x,y) \
  _=x; \
  x -= mul*y>>shift; \
  y += mul*_>>shift; \
  _ = 3145728-x*x-y*y>>11; \
  x = x*_>>10; \
  y = y*_>>10;

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
int8_t b[1760], z[1760];
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
int usleep(int a) {
    for (int i = 0; i < a*50; i++) {
    }
}
void main() {
  int sA=1024,cA=0,sB=1024,cB=0,_;
  for (;;) {
    memset(b, 32, 1760);  // text buffer
    memset(z, 127, 1760);   // z buffer
    int sj=0, cj=1024;
    for (int j = 0; j < 90; j++) {
      int si = 0, ci = 1024;  // sine and cosine of angle i
      for (int i = 0; i < 324; i++) {
        int R1 = 1, R2 = 2048, K2 = 5120*1024;

        int x0 = R1*cj + R2,
            x1 = ci*x0 >> 10,
            x2 = cA*sj >> 10,
            x3 = si*x0 >> 10,
            x4 = R1*x2 - (sA*x3 >> 10),
            x5 = sA*sj >> 10,
            x6 = K2 + R1*1024*x5 + cA*x3,
            x7 = cj*si >> 10,
            x = 40 + 30*(cB*x1 - sB*x4)/x6,
            y = 12 + 15*(cB*x4 + sB*x1)/x6,
            N = (-cA*x7 - cB*((-sA*x7>>10) + x2) - ci*(cj*sB >> 10) >> 10) - x5 >> 7;

        int o = x + 80 * y;
        int8_t zz = (x6-K2)>>15;
        if (22 > y && y > 0 && x > 0 && 80 > x && zz < z[o]) {
          z[o] = zz;
          b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
        }
        R(5, 8, ci, si)  // rotate i
      }
      R(9, 7, cj, sj)  // rotate j
    }
    for (int k = 0; 1761 > k; k++)
      putchar_uart(k % 80 ? b[k] : 10);
    R(5, 7, cA, sA);
    R(5, 8, cB, sB);
    //usleep(15000);
    puts_uart("\x1b[23A");
  }
}



