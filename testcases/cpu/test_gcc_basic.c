int __mulsi3(int a, int b) {
    int r = 0;
    while (b) {
        if (b & 1)
            r += a;
        a <<= 1;
        b >>= 1;
    }
    return r;
}

int main () {
    int a = 3;
    int b = 6;
    a = a + 1;
    a = __mulsi3(a, b);
    a -= 3;
    return a;
}
