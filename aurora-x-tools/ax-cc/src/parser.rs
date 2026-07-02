use crate::lexer::Token;

#[derive(Debug, Clone)]
pub enum ASTNode {
    Program(Vec<Function>),
}

#[derive(Debug, Clone)]
pub struct Function {
    pub name: String,
    pub args: Vec<String>,
    pub body: Vec<Statement>,
}

#[derive(Debug, Clone)]
pub enum Statement {
    Declare(String, Expression),
    Assign(String, Expression),
    If(Expression, Vec<Statement>, Option<Vec<Statement>>),
    While(Expression, Vec<Statement>),
    For(Box<Statement>, Expression, Box<Statement>, Vec<Statement>),
    Return(Expression),
    CallStmt(String, Vec<Expression>),
}

#[derive(Debug, Clone)]
pub enum Expression {
    Number(i32),
    Variable(String),
    BinaryOp(Op, Box<Expression>, Box<Expression>),
    UnaryOp(UnaryOp, Box<Expression>),
    CallExpr(String, Vec<Expression>),
}

#[derive(Debug, Clone, PartialEq)]
pub enum UnaryOp {
    Minus,
    Not,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Op {
    Add,
    Sub,
    Mul,
    Div,
    Eq,
    Neq,
    Lt,
    Gt,
    Le,
    Ge,
    And,
    Or,
}

pub struct Parser<'a> {
    tokens: &'a [Token],
    pos: usize,
}

impl<'a> Parser<'a> {
    pub fn new(tokens: &'a [Token]) -> Self {
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn advance(&mut self) -> Option<&Token> {
        let t = self.tokens.get(self.pos);
        self.pos += 1;
        t
    }

    fn match_token(&mut self, expected: Token) -> bool {
        if self.peek() == Some(&expected) {
            self.advance();
            true
        } else {
            false
        }
    }

    fn expect(&mut self, expected: Token) {
        if !self.match_token(expected.clone()) {
            panic!("Expected {:?}, found {:?}", expected, self.peek());
        }
    }

    pub fn parse_program(&mut self) -> ASTNode {
        let mut funcs = Vec::new();
        while self.peek().is_some() {
            funcs.push(self.parse_function());
        }
        ASTNode::Program(funcs)
    }

    fn parse_function(&mut self) -> Function {
        self.expect(Token::Int);
        let name = if let Some(Token::Identifier(n)) = self.advance() {
            n.clone()
        } else {
            panic!("Expected function name");
        };
        self.expect(Token::LParen);
        let mut args = Vec::new();
        while self.peek() != Some(&Token::RParen) {
            self.expect(Token::Int);
            if let Some(Token::Identifier(arg)) = self.advance() {
                args.push(arg.clone());
            }
            if self.peek() == Some(&Token::Comma) {
                self.advance();
            }
        }
        self.expect(Token::RParen);
        self.expect(Token::LBrace);
        
        let mut body = Vec::new();
        while self.peek() != Some(&Token::RBrace) {
            body.push(self.parse_statement());
        }
        self.expect(Token::RBrace);
        
        Function { name, args, body }
    }

    fn parse_statement(&mut self) -> Statement {
        match self.peek() {
            Some(Token::Int) => {
                self.advance();
                let name = if let Some(Token::Identifier(n)) = self.advance() { n.clone() } else { panic!("Expected identifier"); };
                self.expect(Token::Assign);
                let expr = self.parse_expression();
                self.expect(Token::Semicolon);
                Statement::Declare(name, expr)
            }
            Some(Token::If) => {
                self.advance();
                let has_paren = self.match_token(Token::LParen);
                let condition = self.parse_expression();
                if has_paren {
                    self.expect(Token::RParen);
                }
                self.expect(Token::LBrace);
                let mut body = Vec::new();
                while self.peek() != Some(&Token::RBrace) {
                    body.push(self.parse_statement());
                }
                self.expect(Token::RBrace);
                
                let else_body = if self.match_token(Token::Else) {
                    self.expect(Token::LBrace);
                    let mut e_body = Vec::new();
                    while self.peek() != Some(&Token::RBrace) {
                        e_body.push(self.parse_statement());
                    }
                    self.expect(Token::RBrace);
                    Some(e_body)
                } else {
                    None
                };
                
                Statement::If(condition, body, else_body)
            }
            Some(Token::While) => {
                self.advance();
                let has_paren = self.match_token(Token::LParen);
                let condition = self.parse_expression();
                if has_paren {
                    self.expect(Token::RParen);
                }
                self.expect(Token::LBrace);
                let mut body = Vec::new();
                while self.peek() != Some(&Token::RBrace) {
                    body.push(self.parse_statement());
                }
                self.expect(Token::RBrace);
                Statement::While(condition, body)
            }
            Some(Token::For) => {
                self.advance();
                let has_paren = self.match_token(Token::LParen);
                let init = self.parse_statement();
                let condition = self.parse_expression();
                self.expect(Token::Semicolon);
                let step = self.parse_step_statement();
                if has_paren {
                    self.expect(Token::RParen);
                }
                self.expect(Token::LBrace);
                let mut body = Vec::new();
                while self.peek() != Some(&Token::RBrace) {
                    body.push(self.parse_statement());
                }
                self.expect(Token::RBrace);
                Statement::For(Box::new(init), condition, Box::new(step), body)
            }
            Some(Token::Return) => {
                self.advance();
                let expr = self.parse_expression();
                self.expect(Token::Semicolon);
                Statement::Return(expr)
            }
            Some(Token::Identifier(_)) => {
                let name = if let Some(Token::Identifier(n)) = self.advance() { n.clone() } else { unreachable!() };
                if self.peek() == Some(&Token::LParen) {
                    // Function call
                    self.advance();
                    let mut args = Vec::new();
                    while self.peek() != Some(&Token::RParen) {
                        args.push(self.parse_expression());
                        if self.peek() == Some(&Token::Comma) {
                            self.advance();
                        }
                    }
                    self.expect(Token::RParen);
                    self.expect(Token::Semicolon);
                    Statement::CallStmt(name, args)
                } else if self.peek() == Some(&Token::Assign) {
                    self.advance();
                    let expr = self.parse_expression();
                    self.expect(Token::Semicolon);
                    Statement::Assign(name, expr)
                } else {
                    panic!("Unexpected token after identifier in statement");
                }
            }
            _ => panic!("Unexpected token in statement: {:?}", self.peek()),
        }
    }

    fn parse_step_statement(&mut self) -> Statement {
        match self.peek() {
            Some(Token::Identifier(_)) => {
                let name = if let Some(Token::Identifier(n)) = self.advance() { n.clone() } else { unreachable!() };
                if self.peek() == Some(&Token::Assign) {
                    self.advance();
                    let expr = self.parse_expression();
                    Statement::Assign(name, expr)
                } else if self.peek() == Some(&Token::LParen) {
                    self.advance();
                    let mut args = Vec::new();
                    while self.peek() != Some(&Token::RParen) {
                        args.push(self.parse_expression());
                        if self.peek() == Some(&Token::Comma) {
                            self.advance();
                        }
                    }
                    self.expect(Token::RParen);
                    Statement::CallStmt(name, args)
                } else {
                    panic!("Unexpected token in for-loop step");
                }
            }
            _ => panic!("Expected assignment or call as step in for-loop"),
        }
    }

    fn parse_expression(&mut self) -> Expression {
        self.parse_logical_or()
    }

    fn parse_logical_or(&mut self) -> Expression {
        let mut left = self.parse_logical_and();
        while self.match_token(Token::OrOr) {
            let right = self.parse_logical_and();
            left = Expression::BinaryOp(Op::Or, Box::new(left), Box::new(right));
        }
        left
    }

    fn parse_logical_and(&mut self) -> Expression {
        let mut left = self.parse_equality();
        while self.match_token(Token::AndAnd) {
            let right = self.parse_equality();
            left = Expression::BinaryOp(Op::And, Box::new(left), Box::new(right));
        }
        left
    }

    fn parse_equality(&mut self) -> Expression {
        let mut left = self.parse_comparison();
        while let Some(tok) = self.peek() {
            let op = match tok {
                Token::EqEq => Op::Eq,
                Token::NotEq => Op::Neq,
                _ => break,
            };
            self.advance();
            let right = self.parse_comparison();
            left = Expression::BinaryOp(op, Box::new(left), Box::new(right));
        }
        left
    }

    fn parse_comparison(&mut self) -> Expression {
        let mut left = self.parse_addition();
        while let Some(tok) = self.peek() {
            let op = match tok {
                Token::LessThan => Op::Lt,
                Token::GreaterThan => Op::Gt,
                Token::LessEqual => Op::Le,
                Token::GreaterEqual => Op::Ge,
                _ => break,
            };
            self.advance();
            let right = self.parse_addition();
            left = Expression::BinaryOp(op, Box::new(left), Box::new(right));
        }
        left
    }

    fn parse_addition(&mut self) -> Expression {
        let mut left = self.parse_multiplication();
        while let Some(tok) = self.peek() {
            let op = match tok {
                Token::Plus => Op::Add,
                Token::Minus => Op::Sub,
                _ => break,
            };
            self.advance();
            let right = self.parse_multiplication();
            left = Expression::BinaryOp(op, Box::new(left), Box::new(right));
        }
        left
    }

    fn parse_multiplication(&mut self) -> Expression {
        let mut left = self.parse_unary();
        while let Some(tok) = self.peek() {
            let op = match tok {
                Token::Multiply => Op::Mul,
                Token::Divide => Op::Div,
                _ => break,
            };
            self.advance();
            let right = self.parse_unary();
            left = Expression::BinaryOp(op, Box::new(left), Box::new(right));
        }
        left
    }

    fn parse_unary(&mut self) -> Expression {
        if self.match_token(Token::Minus) {
            let expr = self.parse_unary();
            Expression::UnaryOp(UnaryOp::Minus, Box::new(expr))
        } else if self.match_token(Token::Bang) {
            let expr = self.parse_unary();
            Expression::UnaryOp(UnaryOp::Not, Box::new(expr))
        } else {
            self.parse_primary()
        }
    }

    fn parse_primary(&mut self) -> Expression {
        match self.peek() {
            Some(Token::Number(n)) => {
                let val = *n;
                self.advance();
                Expression::Number(val)
            }
            Some(Token::Identifier(_)) => {
                let name = if let Some(Token::Identifier(n)) = self.advance() { n.clone() } else { unreachable!() };
                if self.peek() == Some(&Token::LParen) {
                    self.advance();
                    let mut args = Vec::new();
                    while self.peek() != Some(&Token::RParen) {
                        args.push(self.parse_expression());
                        if self.peek() == Some(&Token::Comma) {
                            self.advance();
                        }
                    }
                    self.expect(Token::RParen);
                    Expression::CallExpr(name, args)
                } else {
                    Expression::Variable(name)
                }
            }
            Some(Token::LParen) => {
                self.advance();
                let expr = self.parse_expression();
                self.expect(Token::RParen);
                expr
            }
            _ => panic!("Unexpected token in expression: {:?}", self.peek()),
        }
    }
}

pub fn parse(tokens: &[Token]) -> ASTNode {
    let mut parser = Parser::new(tokens);
    parser.parse_program()
}
