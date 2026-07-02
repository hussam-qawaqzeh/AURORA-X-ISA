use crate::parser::{ASTNode, Expression, Function, Op, Statement, UnaryOp};
use std::collections::HashMap;

#[derive(Debug, Clone)]
enum Inst {
    Addi(u8, u8, i32),
    Add(u8, u8, u8),
    Sub(u8, u8, u8),
    Mul(u8, u8, u8),
    Div(u8, u8, u8),
    Xor(u8, u8, u8),
    And(u8, u8, u8),
    Or(u8, u8, u8),
    Shl(u8, u8, u8),
    Shr(u8, u8, u8),
    Slt(u8, u8, u8),
    Sltu(u8, u8, u8),
    Branch(u8, u8, String), // BEQ
    Jump(String),
    CsrWrite(u8, u16),
    Label(String),
}

pub struct CodeGen {
    var_to_reg: HashMap<String, u8>,
    next_reg: u8,
    label_count: usize,
    current_func: String,
}

impl CodeGen {
    pub fn new() -> Self {
        Self {
            var_to_reg: HashMap::new(),
            next_reg: 1, // R1 to R24 for locals
            label_count: 0,
            current_func: String::new(),
        }
    }

    fn new_label(&mut self, prefix: &str) -> String {
        self.label_count += 1;
        format!("{}_{}", prefix, self.label_count)
    }

    fn get_reg(&mut self, name: &str) -> u8 {
        if let Some(&r) = self.var_to_reg.get(name) {
            r
        } else {
            let r = self.next_reg;
            self.next_reg += 1;
            if self.next_reg > 24 { panic!("Out of registers!"); }
            self.var_to_reg.insert(name.to_string(), r);
            r
        }
    }

    pub fn generate(&mut self, ast: &ASTNode) -> String {
        let mut asm = Vec::new();
        if let ASTNode::Program(funcs) = ast {
            for func in funcs {
                self.gen_func(func, &mut asm);
            }
        }
        self.resolve_labels(asm)
    }

    fn gen_func(&mut self, func: &Function, asm: &mut Vec<Inst>) {
        self.var_to_reg.clear();
        self.next_reg = 1;
        self.current_func = func.name.clone();
        
        // Setup args
        for arg in &func.args {
            self.get_reg(arg); // Allocate registers for args
        }

        for stmt in &func.body {
            self.gen_stmt(stmt, asm);
        }
        
        if func.name == "main" {
            let end_label = self.new_label("end_func");
            asm.push(Inst::Label(end_label.clone()));
            asm.push(Inst::Jump(end_label)); // infinite loop at end of main
        }
    }

    fn gen_stmt(&mut self, stmt: &Statement, asm: &mut Vec<Inst>) {
        match stmt {
            Statement::Declare(name, expr) => {
                let r = self.get_reg(name);
                let res_r = self.gen_expr(expr, asm, 0);
                if r != res_r {
                    asm.push(Inst::Addi(r, res_r, 0)); // Move
                }
            }
            Statement::Assign(name, expr) => {
                let r = self.get_reg(name);
                let res_r = self.gen_expr(expr, asm, 0);
                if r != res_r {
                    asm.push(Inst::Addi(r, res_r, 0));
                }
            }
            Statement::If(cond, body, else_body) => {
                let cond_reg = self.gen_expr(cond, asm, 0);
                if let Some(else_stmts) = else_body {
                    let else_label = self.new_label("if_else");
                    let end_label = self.new_label("if_end");
                    asm.push(Inst::Branch(cond_reg, 0, else_label.clone()));
                    for s in body {
                        self.gen_stmt(s, asm);
                    }
                    asm.push(Inst::Jump(end_label.clone()));
                    asm.push(Inst::Label(else_label));
                    for s in else_stmts {
                        self.gen_stmt(s, asm);
                    }
                    asm.push(Inst::Label(end_label));
                } else {
                    let end_label = self.new_label("if_end");
                    asm.push(Inst::Branch(cond_reg, 0, end_label.clone()));
                    for s in body {
                        self.gen_stmt(s, asm);
                    }
                    asm.push(Inst::Label(end_label));
                }
            }
            Statement::While(cond, body) => {
                let start_label = self.new_label("while_start");
                let end_label = self.new_label("while_end");
                
                asm.push(Inst::Label(start_label.clone()));
                
                let cond_reg = self.gen_expr(cond, asm, 0);
                asm.push(Inst::Branch(cond_reg, 0, end_label.clone()));
                
                for s in body {
                    self.gen_stmt(s, asm);
                }
                
                asm.push(Inst::Jump(start_label));
                asm.push(Inst::Label(end_label));
            }
            Statement::For(init, cond, step, body) => {
                let start_label = self.new_label("for_start");
                let end_label = self.new_label("for_end");
                
                self.gen_stmt(init, asm);
                
                asm.push(Inst::Label(start_label.clone()));
                
                let cond_reg = self.gen_expr(cond, asm, 0);
                asm.push(Inst::Branch(cond_reg, 0, end_label.clone()));
                
                for s in body {
                    self.gen_stmt(s, asm);
                }
                
                self.gen_stmt(step, asm);
                
                asm.push(Inst::Jump(start_label));
                asm.push(Inst::Label(end_label));
            }
            Statement::Return(expr) => {
                let res_r = self.gen_expr(expr, asm, 0);
                if self.current_func == "main" {
                    asm.push(Inst::CsrWrite(res_r, 0x700));
                } else {
                    asm.push(Inst::Addi(1, res_r, 0)); // Return result in R1
                    // Since dynamic jump is not in hardware, compile return as a simple exit or no-op
                }
            }
            Statement::CallStmt(name, args) => {
                if name == "print" && args.len() == 1 {
                    let r = self.gen_expr(&args[0], asm, 0);
                    asm.push(Inst::CsrWrite(r, 0x701));
                } else {
                    panic!("Unsupported function call: {}", name);
                }
            }
        }
    }

    fn emit_load_u32(&self, asm: &mut Vec<Inst>, r: u8, val: u32, temp_idx: u8) {
        if val < 8192 {
            asm.push(Inst::Addi(r, 0, val as i32));
        } else {
            let high = val >> 12;
            let low = val & 0xFFF;
            let next_temp_idx = temp_idx + 1;
            
            // Load high into r
            self.emit_load_u32(asm, r, high, next_temp_idx);
            
            // Load shift amount 12 into a temp register
            let r_shift = 25 + next_temp_idx;
            if r_shift > 30 { panic!("Out of temp registers during constant loading!"); }
            asm.push(Inst::Addi(r_shift, 0, 12));
            
            // Shift left
            asm.push(Inst::Shl(r, r, r_shift));
            
            // Add low part if not zero
            if low != 0 {
                asm.push(Inst::Addi(r_shift, 0, low as i32));
                asm.push(Inst::Add(r, r, r_shift));
            }
        }
    }

    fn gen_expr(&mut self, expr: &Expression, asm: &mut Vec<Inst>, temp_idx: u8) -> u8 {
        match expr {
            Expression::Number(n) => {
                let r = 25 + temp_idx; // Temp register starts at 25
                if r > 30 { panic!("Out of temp registers!"); } // R31 is reserved for local scratch
                let val = *n;
                if val >= -8192 && val <= 8191 {
                    asm.push(Inst::Addi(r, 0, val));
                } else if val < 0 {
                    let abs_val = (-val) as u32;
                    self.emit_load_u32(asm, r, abs_val, temp_idx);
                    asm.push(Inst::Sub(r, 0, r)); // Negate: r = R0 - r
                } else {
                    self.emit_load_u32(asm, r, val as u32, temp_idx);
                }
                r
            }
            Expression::Variable(name) => {
                self.get_reg(name)
            }
            Expression::UnaryOp(op, inner) => {
                let res_reg = 25 + temp_idx;
                if res_reg > 30 { panic!("Out of temp registers!"); }
                let inner_reg = self.gen_expr(inner, asm, temp_idx);
                match op {
                    UnaryOp::Minus => {
                        asm.push(Inst::Sub(res_reg, 0, inner_reg));
                    }
                    UnaryOp::Not => {
                        // !x is equivalent to x == 0
                        // SLTU scratch, R0, inner_reg (1 if inner_reg != 0, else 0)
                        // XOR res_reg, scratch, 1
                        let scratch = 31;
                        asm.push(Inst::Sltu(scratch, 0, inner_reg));
                        asm.push(Inst::Addi(res_reg, 0, 1));
                        asm.push(Inst::Xor(res_reg, scratch, res_reg));
                    }
                }
                res_reg
            }
            Expression::BinaryOp(op, left, right) => {
                let res_reg = 25 + temp_idx;
                if res_reg > 30 { panic!("Out of temp registers!"); }
                
                let l_reg = self.gen_expr(left, asm, temp_idx);
                let r_reg = self.gen_expr(right, asm, temp_idx + 1);
                
                match op {
                    Op::Add => asm.push(Inst::Add(res_reg, l_reg, r_reg)),
                    Op::Sub => asm.push(Inst::Sub(res_reg, l_reg, r_reg)),
                    Op::Mul => asm.push(Inst::Mul(res_reg, l_reg, r_reg)),
                    Op::Div => asm.push(Inst::Div(res_reg, l_reg, r_reg)),
                    Op::Eq => {
                        let true_label = self.new_label("eq_true");
                        let end_label = self.new_label("eq_end");
                        asm.push(Inst::Branch(l_reg, r_reg, true_label.clone()));
                        asm.push(Inst::Addi(res_reg, 0, 0)); // false
                        asm.push(Inst::Jump(end_label.clone()));
                        asm.push(Inst::Label(true_label));
                        asm.push(Inst::Addi(res_reg, 0, 1)); // true
                        asm.push(Inst::Label(end_label));
                    }
                    Op::Neq => {
                        let true_label = self.new_label("neq_true");
                        let end_label = self.new_label("neq_end");
                        asm.push(Inst::Branch(l_reg, r_reg, true_label.clone()));
                        asm.push(Inst::Addi(res_reg, 0, 1)); // true
                        asm.push(Inst::Jump(end_label.clone()));
                        asm.push(Inst::Label(true_label));
                        asm.push(Inst::Addi(res_reg, 0, 0)); // false
                        asm.push(Inst::Label(end_label));
                    }
                    Op::Lt => {
                        asm.push(Inst::Slt(res_reg, l_reg, r_reg));
                    }
                    Op::Gt => {
                        asm.push(Inst::Slt(res_reg, r_reg, l_reg));
                    }
                    Op::Le => {
                        // a <= b is equivalent to !(a > b) -> !(b < a)
                        let scratch = 31;
                        asm.push(Inst::Slt(scratch, r_reg, l_reg));
                        asm.push(Inst::Addi(res_reg, 0, 1));
                        asm.push(Inst::Xor(res_reg, scratch, res_reg));
                    }
                    Op::Ge => {
                        // a >= b is equivalent to !(a < b)
                        let scratch = 31;
                        asm.push(Inst::Slt(scratch, l_reg, r_reg));
                        asm.push(Inst::Addi(res_reg, 0, 1));
                        asm.push(Inst::Xor(res_reg, scratch, res_reg));
                    }
                    Op::And => {
                        let false_label = self.new_label("and_false");
                        let end_label = self.new_label("and_end");
                        asm.push(Inst::Branch(l_reg, 0, false_label.clone()));
                        asm.push(Inst::Branch(r_reg, 0, false_label.clone()));
                        asm.push(Inst::Addi(res_reg, 0, 1)); // true
                        asm.push(Inst::Jump(end_label.clone()));
                        asm.push(Inst::Label(false_label));
                        asm.push(Inst::Addi(res_reg, 0, 0)); // false
                        asm.push(Inst::Label(end_label));
                    }
                    Op::Or => {
                        let check_right_label = self.new_label("or_check_right");
                        let end_label = self.new_label("or_end");
                        asm.push(Inst::Addi(res_reg, 0, 0)); // default to false
                        asm.push(Inst::Branch(l_reg, 0, check_right_label.clone()));
                        asm.push(Inst::Addi(res_reg, 0, 1)); // true
                        asm.push(Inst::Jump(end_label.clone()));
                        asm.push(Inst::Label(check_right_label));
                        asm.push(Inst::Branch(r_reg, 0, end_label.clone()));
                        asm.push(Inst::Addi(res_reg, 0, 1)); // true
                        asm.push(Inst::Label(end_label));
                    }
                }
                res_reg
            }
            Expression::CallExpr(name, args) => {
                if name == "print" && args.len() == 1 {
                    let r = self.gen_expr(&args[0], asm, temp_idx);
                    asm.push(Inst::CsrWrite(r, 0x701));
                    r
                } else {
                    panic!("Function calls in expressions not implemented");
                }
            }
        }
    }

    fn resolve_labels(&self, asm: Vec<Inst>) -> String {
        let mut resolved = String::new();
        let mut label_map = HashMap::new();
        let mut pc = 0;
        
        // Pass 1: compute addresses
        for inst in &asm {
            match inst {
                Inst::Label(name) => {
                    label_map.insert(name.clone(), pc);
                }
                _ => pc += 1,
            }
        }
        
        // Pass 2: emit text
        pc = 0;
        for inst in &asm {
            match inst {
                Inst::Label(name) => {
                    resolved.push_str(&format!("; {}:\n", name));
                }
                Inst::Addi(rd, rs1, imm) => {
                    resolved.push_str(&format!("    ADDI R{}, R{}, {}\n", rd, rs1, imm));
                    pc += 1;
                }
                Inst::Add(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    ADD.X R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Sub(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    SUB.X R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Mul(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    MUL.X R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Div(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    DIV.X R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Xor(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    XOR R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::And(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    AND R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Or(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    OR R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Shl(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    SHL R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Shr(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    SHR R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Slt(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    SLT R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Sltu(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    SLTU R{}, R{}, R{}\n", rd, rs1, rs2));
                    pc += 1;
                }
                Inst::Branch(rs1, rs2, label) => {
                    let target = label_map.get(label).unwrap();
                    let offset = *target as i32 - pc as i32;
                    resolved.push_str(&format!("    BRANCH.X R{}, R{}, {}\n", rs1, rs2, offset));
                    pc += 1;
                }
                Inst::Jump(label) => {
                    let target = label_map.get(label).unwrap();
                    let offset = *target as i32 - pc as i32;
                    resolved.push_str(&format!("    JUMP.X R0, {}\n", offset));
                    pc += 1;
                }
                Inst::CsrWrite(rs1, addr) => {
                    resolved.push_str(&format!("    CSR.WRITE R{}, 0x{:03X}\n", rs1, addr));
                    pc += 1;
                }
            }
        }
        resolved
    }
}

pub fn generate(ast: &ASTNode) -> String {
    let mut cg = CodeGen::new();
    cg.generate(ast)
}
