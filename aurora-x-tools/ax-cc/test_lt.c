fn main() {
    let a = 5;
    let b = 10;
    
    // a < b => 5 < 10, should print 1
    if a < b {
        print(1);
    }
    
    // a > b => 5 > 10, should NOT print 2
    if a > b {
        print(2);
    }
    
    // b > a => 10 > 5, should print 3
    if b > a {
        print(3);
    }
}
