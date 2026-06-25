use crate::parser::{ASTNode, Expression, Function, Op, Statement};
use std::collections::HashMap;

#[derive(Debug, Clone)]
enum Inst {
    Addi(u8, u8, i32),
    Add(u8, u8, u8),
    Sub(u8, u8, u8),
    Mul(u8, u8, u8),
    Div(u8, u8, u8),
    Shr(u8, u8, u8),
    Branch(u8, u8, String), // BEQ
    Jump(String),
    CsrWrite(u8, u16),
    Label(String),
}

pub struct CodeGen {
    var_to_reg: HashMap<String, u8>,
    next_reg: u8,
    label_count: usize,
}

impl CodeGen {
    pub fn new() -> Self {
        Self {
            var_to_reg: HashMap::new(),
            next_reg: 1, // R1 to R24 for locals
            label_count: 0,
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
            Statement::If(cond, body) => {
                let end_label = self.new_label("if_end");
                let cond_reg = self.gen_expr(cond, asm, 0);
                asm.push(Inst::Branch(cond_reg, 0, end_label.clone()));
                
                for s in body {
                    self.gen_stmt(s, asm);
                }
                
                asm.push(Inst::Label(end_label));
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
            Statement::Return(expr) => {
                let res_r = self.gen_expr(expr, asm, 0);
                asm.push(Inst::CsrWrite(res_r, 0x700));
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

    fn gen_expr(&mut self, expr: &Expression, asm: &mut Vec<Inst>, temp_idx: u8) -> u8 {
        match expr {
            Expression::Number(n) => {
                let r = 25 + temp_idx; // Temp register starts at 25
                if r > 31 { panic!("Out of temp registers!"); }
                asm.push(Inst::Addi(r, 0, *n));
                r
            }
            Expression::Variable(name) => {
                self.get_reg(name)
            }
            Expression::BinaryOp(op, left, right) => {
                let res_reg = 25 + temp_idx;
                if res_reg > 31 { panic!("Out of temp registers!"); }
                
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
                        asm.push(Inst::Sub(res_reg, l_reg, r_reg));
                        let shift_amt_reg = 25 + temp_idx + 1;
                        if shift_amt_reg > 31 { panic!("Out of temp registers!"); }
                        asm.push(Inst::Addi(shift_amt_reg, 0, 63));
                        asm.push(Inst::Shr(res_reg, res_reg, shift_amt_reg));
                    }
                    Op::Gt => {
                        asm.push(Inst::Sub(res_reg, r_reg, l_reg));
                        let shift_amt_reg = 25 + temp_idx + 1;
                        if shift_amt_reg > 31 { panic!("Out of temp registers!"); }
                        asm.push(Inst::Addi(shift_amt_reg, 0, 63));
                        asm.push(Inst::Shr(res_reg, res_reg, shift_amt_reg));
                    }
                }
                res_reg
            }
            Expression::CallExpr(_, _) => panic!("Function calls in expressions not implemented"),
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
                Inst::Shr(rd, rs1, rs2) => {
                    resolved.push_str(&format!("    SHR R{}, R{}, R{}\n", rd, rs1, rs2));
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
