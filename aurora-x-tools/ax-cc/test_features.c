fn main() {
    let a = 5;
    let b = 10;
    
    // 1. Test If-Else
    if a > b {
        print(99);
    } else {
        print(1); // should print 1
    }
    
    // 2. Test <= and >=
    if a <= 5 {
        print(2); // should print 2
    }
    if b >= 10 {
        print(3); // should print 3
    }
    
    // 3. Test Unary Minus and Not
    let c = -5;
    if !c {
        print(99);
    } else {
        print(4); // should print 4 (since !(-5) is false)
    }
    
    let d = 0;
    if !d {
        print(5); // should print 5
    }
    
    // 4. Test Logical AND/OR
    if a == 5 && b == 10 {
        print(6); // should print 6
    }
    if a == 99 && b == 10 {
        print(99);
    }
    
    if a == 99 || b == 10 {
        print(7); // should print 7
    }
    
    // 5. Test For loop
    let sum = 0;
    let i = 0;
    for i = 0; i < 5; i = i + 1 {
        sum = sum + i;
    }
    print(sum); // should print 0+1+2+3+4 = 10
}
