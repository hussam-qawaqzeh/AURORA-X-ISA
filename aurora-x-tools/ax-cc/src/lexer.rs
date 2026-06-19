#[derive(Debug, PartialEq, Clone)]
pub enum Token {
    Int,
    If,
    While,
    Return,
    Identifier(String),
    Number(i32),
    Assign,
    Plus,
    Minus,
    Multiply,
    Divide,
    EqEq,
    NotEq,
    LessThan,
    GreaterThan,
    LBrace,
    RBrace,
    LParen,
    RParen,
    Semicolon,
    Comma,
}

pub fn lex(code: &str) -> Vec<Token> {
    let mut tokens = Vec::new();
    let mut chars = code.chars().peekable();

    while let Some(&c) = chars.peek() {
        match c {
            ' ' | '\t' | '\n' | '\r' => {
                chars.next();
            }
            '+' => { tokens.push(Token::Plus); chars.next(); }
            '-' => { tokens.push(Token::Minus); chars.next(); }
            '*' => { tokens.push(Token::Multiply); chars.next(); }
            '/' => {
                chars.next();
                if let Some(&'/') = chars.peek() {
                    // Line comment
                    while let Some(&c) = chars.peek() {
                        if c == '\n' { break; }
                        chars.next();
                    }
                } else {
                    tokens.push(Token::Divide);
                }
            }
            '=' => {
                chars.next();
                if let Some(&'=') = chars.peek() {
                    tokens.push(Token::EqEq);
                    chars.next();
                } else {
                    tokens.push(Token::Assign);
                }
            }
            '<' => { tokens.push(Token::LessThan); chars.next(); }
            '>' => { tokens.push(Token::GreaterThan); chars.next(); }
            '!' => {
                chars.next();
                if let Some(&'=') = chars.peek() {
                    tokens.push(Token::NotEq);
                    chars.next();
                } else {
                    panic!("Unexpected !");
                }
            }
            '{' => { tokens.push(Token::LBrace); chars.next(); }
            '}' => { tokens.push(Token::RBrace); chars.next(); }
            '(' => { tokens.push(Token::LParen); chars.next(); }
            ')' => { tokens.push(Token::RParen); chars.next(); }
            ';' => { tokens.push(Token::Semicolon); chars.next(); }
            ',' => { tokens.push(Token::Comma); chars.next(); }
            '0'..='9' => {
                let mut num_str = String::new();
                while let Some(&c) = chars.peek() {
                    if c.is_ascii_digit() {
                        num_str.push(c);
                        chars.next();
                    } else {
                        break;
                    }
                }
                tokens.push(Token::Number(num_str.parse().unwrap()));
            }
            'a'..='z' | 'A'..='Z' | '_' => {
                let mut id_str = String::new();
                while let Some(&c) = chars.peek() {
                    if c.is_ascii_alphanumeric() || c == '_' {
                        id_str.push(c);
                        chars.next();
                    } else {
                        break;
                    }
                }
                match id_str.as_str() {
                    "int" => tokens.push(Token::Int),
                    "if" => tokens.push(Token::If),
                    "while" => tokens.push(Token::While),
                    "return" => tokens.push(Token::Return),
                    _ => tokens.push(Token::Identifier(id_str)),
                }
            }
            _ => panic!("Unexpected character: {}", c),
        }
    }
    tokens
}
