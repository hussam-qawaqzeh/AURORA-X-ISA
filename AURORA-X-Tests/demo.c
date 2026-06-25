int main() {
    int sum = 0;
    int i = 1;
    int run = 1;

    while (run == 1) {
        sum = sum + i;
        i = i + 1;
        
        if (i == 11) {
            run = 0;
        }
    }

    // Output should be 55
    print(sum);
    
    return 1;
}
