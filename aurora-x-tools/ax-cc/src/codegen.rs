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
    Load(u8, u8, i32),
    Store(u8, u8, i32),
}

pub struct CodeGen {
    var_to_reg: HashMap<String, u8>,
    next_reg: u8,
    label_count: usize,
    current_func: String,
    func_call_sites: HashMap<String, Vec<String>>,
    func_call_counts: HashMap<String, usize>,
}

impl CodeGen {
    pub fn new() -> Self {
        Self {
            var_to_reg: HashMap::new(),
            next_reg: 1, // R1 to R23 for locals (R24 is SP)
            label_count: 0,
            current_func: String::new(),
            func_call_sites: HashMap::new(),
            func_call_counts: HashMap::new(),
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
            if self.next_reg > 23 { panic!("Out of registers! R24 is reserved for Stack Pointer."); }
            self.var_to_reg.insert(name.to_string(), r);
            r
        }
    }

    pub fn generate(&mut self, ast: &ASTNode) -> String {
        let mut asm = Vec::new();
        if let ASTNode::Program(funcs) = ast {
            // Pass 0: Collect function call sites
            self.collect_call_sites(ast);

            // First emit main at PC 0 (entry point)
            if let Some(main_func) = funcs.iter().find(|f| f.name == "main") {
                // Initialize SP = 1048576 (R24)
                self.emit_load_u32(&mut asm, 24, 1048576, 0);
                self.gen_func(main_func, &mut asm);
            }
            // Then emit other functions
            for func in funcs {
                if func.name != "main" {
                    self.gen_func(func, &mut asm);
                }
            }
        }
        self.resolve_labels(asm)
    }

    fn collect_call_sites(&mut self, ast: &ASTNode) {
        if let ASTNode::Program(funcs) = ast {
            for func in funcs {
                for stmt in &func.body {
                    self.collect_call_sites_stmt(stmt);
                }
            }
        }
    }

    fn collect_call_sites_stmt(&mut self, stmt: &Statement) {
        match stmt {
            Statement::Declare(_, expr) => self.collect_call_sites_expr(expr),
            Statement::Assign(_, expr) => self.collect_call_sites_expr(expr),
            Statement::If(cond, body, else_body) => {
                self.collect_call_sites_expr(cond);
                for s in body { self.collect_call_sites_stmt(s); }
                if let Some(eb) = else_body {
                    for s in eb { self.collect_call_sites_stmt(s); }
                }
            }
            Statement::While(cond, body) => {
                self.collect_call_sites_expr(cond);
                for s in body { self.collect_call_sites_stmt(s); }
            }
            Statement::For(init, cond, step, body) => {
                self.collect_call_sites_stmt(init);
                self.collect_call_sites_expr(cond);
                self.collect_call_sites_stmt(step);
                for s in body { self.collect_call_sites_stmt(s); }
            }
            Statement::Return(expr) => self.collect_call_sites_expr(expr),
            Statement::CallStmt(name, args) => {
                if name != "print" {
                    let lbl = self.new_label(&format!("ret_{}", name));
                    self.func_call_sites.entry(name.clone()).or_default().push(lbl);
                }
                for arg in args { self.collect_call_sites_expr(arg); }
            }
        }
    }

    fn collect_call_sites_expr(&mut self, expr: &Expression) {
        match expr {
            Expression::BinaryOp(_, lhs, rhs) => {
                self.collect_call_sites_expr(lhs);
                self.collect_call_sites_expr(rhs);
            }
            Expression::UnaryOp(_, inner) => {
                self.collect_call_sites_expr(inner);
            }
            Expression::CallExpr(name, args) => {
                if name != "print" {
                    let lbl = self.new_label(&format!("ret_{}", name));
                    self.func_call_sites.entry(name.clone()).or_default().push(lbl);
                }
                for arg in args { self.collect_call_sites_expr(arg); }
            }
            _ => {}
        }
    }

    fn gen_func(&mut self, func: &Function, asm: &mut Vec<Inst>) {
        self.var_to_reg.clear();
        self.next_reg = 1;
        self.current_func = func.name.clone();
        
        // Emit entry label
        asm.push(Inst::Label(func.name.clone()));
        
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
        } else {
            let disp_label = format!("disp_{}", func.name);
            asm.push(Inst::Label(disp_label));
            self.emit_dispatch(&func.name, asm);
        }
    }

    fn emit_dispatch(&mut self, func_name: &str, asm: &mut Vec<Inst>) {
        if let Some(sites) = self.func_call_sites.get(func_name) {
            let sites = sites.clone();
            for (idx, label) in sites.iter().enumerate() {
                let call_id = idx + 1;
                let r_temp = 25; // R25-R30 scratch
                asm.push(Inst::Addi(r_temp, 0, call_id as i32));
                asm.push(Inst::Branch(30, r_temp, label.clone()));
            }
        }
        // Fallback / infinite loop safety
        asm.push(Inst::Jump(format!("disp_{}", func_name)));
    }

    fn gen_call(&mut self, name: &str, args: &[Expression], asm: &mut Vec<Inst>, temp_idx: u8) -> u8 {
        // 1. Evaluate args into temp registers
        let mut arg_regs = Vec::new();
        let mut current_temp = temp_idx;
        for arg in args {
            let r = self.gen_expr(arg, asm, current_temp);
            arg_regs.push(r);
            current_temp += 1;
        }

        // 2. Spill active local registers onto stack (R1 to next_reg-1)
        let mut saved_regs = Vec::new();
        for r in 1..self.next_reg {
            saved_regs.push(r);
        }
        // Spill Link register R30
        saved_regs.push(30);

        for &r in &saved_regs {
            asm.push(Inst::Addi(24, 24, -8)); // push SP
            asm.push(Inst::Store(r, 24, 0));
        }

        // 3. Move arguments to R1, R2, ...
        for (i, &arg_r) in arg_regs.iter().enumerate() {
            let target_r = (i + 1) as u8;
            asm.push(Inst::Addi(target_r, arg_r, 0));
        }

        // 4. Set R30 to return site ID
        let call_idx = *self.func_call_counts.entry(name.to_string()).or_default();
        self.func_call_counts.insert(name.to_string(), call_idx + 1);
        
        let return_label = self.func_call_sites.get(name).unwrap()[call_idx].clone();
        let return_id = (call_idx + 1) as i32;
        asm.push(Inst::Addi(30, 0, return_id));

        // 5. Jump to function entry
        asm.push(Inst::Jump(name.to_string()));

        // 6. Emit return label
        asm.push(Inst::Label(return_label));

        // Return value is in R1. Move to a temp first before POP clobbers it
        let res_reg = 25 + temp_idx;
        if res_reg > 30 { panic!("Out of temp registers!"); }
        asm.push(Inst::Addi(res_reg, 1, 0));

        // 7. Pop saved registers from stack (reverse order)
        for &r in saved_regs.iter().rev() {
            asm.push(Inst::Load(r, 24, 0));
            asm.push(Inst::Addi(24, 24, 8)); // pop SP
        }
        res_reg
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
                    if res_r != 1 {
                        asm.push(Inst::Addi(1, res_r, 0));
                    }
                    let disp_label = format!("disp_{}", self.current_func);
                    asm.push(Inst::Jump(disp_label));
                }
            }
            Statement::CallStmt(name, args) => {
                if name == "print" && args.len() == 1 {
                    let r = self.gen_expr(&args[0], asm, 0);
                    asm.push(Inst::CsrWrite(r, 0x701));
                } else {
                    self.gen_call(name, args, asm, 0);
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
                    self.gen_call(name, args, asm, temp_idx)
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
                Inst::Load(rd, rs1, imm) => {
                    resolved.push_str(&format!("    LOAD.X R{}, [R{}+{}]\n", rd, rs1, imm));
                    pc += 1;
                }
                Inst::Store(rs2, rs1, imm) => {
                    resolved.push_str(&format!("    STORE.X R{}, [R{}+{}]\n", rs2, rs1, imm));
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
