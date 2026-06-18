int recurse (int a) {
    if (a > 3) {
        return recurse(a-3);
    }
    return a;
}
int main () {
    return recurse(200);
}
