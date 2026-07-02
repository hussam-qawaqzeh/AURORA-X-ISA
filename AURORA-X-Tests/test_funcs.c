int add(int x, int y) {
    return x + y;
}

int double_add(int x, int y) {
    int a = add(x, y);
    int b = add(x, y);
    return a + b;
}

int main() {
    int res = double_add(5, 10);
    print(res);
    return 1;
}
