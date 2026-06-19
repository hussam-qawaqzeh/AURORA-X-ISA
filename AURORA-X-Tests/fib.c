int main() {
    int n = 10;
    int a = 0;
    int b = 1;
    int i = 0;
    int run = 1;

    while (run == 1) {
        int temp = a + b;
        a = b;
        b = temp;
        i = i + 1;
        
        if (i == n) {
            run = 0;
        }
    }

    // Output should be 55 (the 10th Fibonacci number)
    print(a);
    
    return 0;
}
