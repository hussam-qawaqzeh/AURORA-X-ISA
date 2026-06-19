//===-- AuroraXInstrFormats.td - AuroraX Instruction Formats -*- tablegen -*-===//
//
// Defines the 32-bit instruction formats for AURORA-X.
//
//===----------------------------------------------------------------------===//

class AuroraXInst<dag outs, dag ins, string asmstr, list<dag> pattern>
  : Instruction {
  field bits<32> Inst;
  
  let Namespace = "AuroraX";
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
}

//--- R-Type Format (Register-Register) ---
// [31:24 opcode] [23:19 rd] [18:14 rs1] [13:9 rs2] [8:0 funct9]
class FR<bits<8> opcode, bits<9> funct9, dag outs, dag ins, string asmstr, list<dag> pattern>
  : AuroraXInst<outs, ins, asmstr, pattern> {
  bits<5> rd;
  bits<5> rs1;
  bits<5> rs2;
  
  let Inst{31-24} = opcode;
  let Inst{23-19} = rd;
  let Inst{18-14} = rs1;
  let Inst{13-9}  = rs2;
  let Inst{8-0}   = funct9;
}

//--- I-Type Format (Immediate) ---
// [31:24 opcode] [23:19 rd] [18:14 rs1] [13:0 imm14]
class FI<bits<8> opcode, dag outs, dag ins, string asmstr, list<dag> pattern>
  : AuroraXInst<outs, ins, asmstr, pattern> {
  bits<5> rd;
  bits<5> rs1;
  bits<14> imm14;
  
  let Inst{31-24} = opcode;
  let Inst{23-19} = rd;
  let Inst{18-14} = rs1;
  let Inst{13-0}  = imm14;
}

//--- S-Type Format (Store) ---
// [31:24 opcode] [23:19 rs1] [18:14 rs2] [13:0 imm14]
class FS<bits<8> opcode, dag outs, dag ins, string asmstr, list<dag> pattern>
  : AuroraXInst<outs, ins, asmstr, pattern> {
  bits<5> rs1;
  bits<5> rs2;
  bits<14> imm14;
  
  let Inst{31-24} = opcode;
  let Inst{23-19} = rs1;
  let Inst{18-14} = rs2;
  let Inst{13-0}  = imm14;
}

//--- B-Type Format (Branch) ---
// [31:24 opcode] [23:19 rs1] [18:14 rs2] [13:0 imm14]
class FB<bits<8> opcode, dag outs, dag ins, string asmstr, list<dag> pattern>
  : AuroraXInst<outs, ins, asmstr, pattern> {
  bits<5> rs1;
  bits<5> rs2;
  bits<14> imm14;
  
  let Inst{31-24} = opcode;
  let Inst{23-19} = rs1;
  let Inst{18-14} = rs2;
  let Inst{13-0}  = imm14;
}

//--- J-Type Format (Jump) ---
// [31:24 opcode] [23:19 rd] [18:0 imm19]
class FJ<bits<8> opcode, dag outs, dag ins, string asmstr, list<dag> pattern>
  : AuroraXInst<outs, ins, asmstr, pattern> {
  bits<5> rd;
  bits<19> imm19;
  
  let Inst{31-24} = opcode;
  let Inst{23-19} = rd;
  let Inst{18-0}  = imm19;
}
