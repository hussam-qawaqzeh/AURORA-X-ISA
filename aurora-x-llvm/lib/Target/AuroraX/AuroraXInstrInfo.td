//===-- AuroraXInstrInfo.td - AuroraX Instruction defs ----*- tablegen -*-===//
//
// Defines the actual instructions and their LLVM IR SelectionDAG mapping.
//
//===----------------------------------------------------------------------===//

include "AuroraXInstrFormats.td"

//===----------------------------------------------------------------------===//
// Integer Arithmetic Instructions (R-Type)
//===----------------------------------------------------------------------===//

def ADDX : FR<0x01, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "ADD.X $rd, $rs1, $rs2",
              [(set GPR:$rd, (add GPR:$rs1, GPR:$rs2))]>;

def SUBX : FR<0x01, 0x01, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "SUB.X $rd, $rs1, $rs2",
              [(set GPR:$rd, (sub GPR:$rs1, GPR:$rs2))]>;

def MULX : FR<0x07, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "MUL.X $rd, $rs1, $rs2",
              [(set GPR:$rd, (mul GPR:$rs1, GPR:$rs2))]>;

def DIVX : FR<0x08, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "DIV.X $rd, $rs1, $rs2",
              [(set GPR:$rd, (udiv GPR:$rs1, GPR:$rs2))]>;

//===----------------------------------------------------------------------===//
// Logical & Shift Instructions (R-Type)
//===----------------------------------------------------------------------===//

def ANDX : FR<0x02, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "AND $rd, $rs1, $rs2",
              [(set GPR:$rd, (and GPR:$rs1, GPR:$rs2))]>;

def ORX  : FR<0x03, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "OR $rd, $rs1, $rs2",
              [(set GPR:$rd, (or GPR:$rs1, GPR:$rs2))]>;

def XORX : FR<0x04, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "XOR $rd, $rs1, $rs2",
              [(set GPR:$rd, (xor GPR:$rs1, GPR:$rs2))]>;

def SHL  : FR<0x05, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "SHL $rd, $rs1, $rs2",
              [(set GPR:$rd, (shl GPR:$rs1, GPR:$rs2))]>;

def SHR  : FR<0x06, 0x02, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "SHR $rd, $rs1, $rs2",
              [(set GPR:$rd, (srl GPR:$rs1, GPR:$rs2))]>;

def SRA  : FR<0x06, 0x01, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "SRA $rd, $rs1, $rs2",
              [(set GPR:$rd, (sra GPR:$rs1, GPR:$rs2))]>;

//===----------------------------------------------------------------------===//
// Comparison & Immediate Instructions (R-Type & I-Type)
//===----------------------------------------------------------------------===//

def SLT  : FR<0x0A, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "SLT $rd, $rs1, $rs2",
              [(set GPR:$rd, (slt GPR:$rs1, GPR:$rs2))]>;

def SLTU : FR<0x0B, 0x00, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
              "SLTU $rd, $rs1, $rs2",
              [(set GPR:$rd, (ult GPR:$rs1, GPR:$rs2))]>;

def ADDI : FI<0x09, (outs GPR:$rd), (ins GPR:$rs1, i14imm:$imm14),
              "ADDI $rd, $rs1, $imm14",
              [(set GPR:$rd, (add GPR:$rs1, imm:$imm14))]>;

//===----------------------------------------------------------------------===//
// Memory Load/Store Instructions (I-Type & S-Type)
//===----------------------------------------------------------------------===//

// We define an operand type for memory addresses (Base Register + 14-bit Imm)
def MemOperand : Operand<i64> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i14imm);
}

def LOADX : FI<0x21, (outs GPR:$rd), (ins MemOperand:$addr),
               "LOAD.X $rd, [$addr]",
               [(set GPR:$rd, (load addr:$addr))]>;

def STOREX : FS<0x22, (outs), (ins GPR:$rs2, MemOperand:$addr),
                "STORE.X $rs2, [$addr]",
                [(store GPR:$rs2, addr:$addr)]>;

//===----------------------------------------------------------------------===//
// Vector Arithmetic Instructions
//===----------------------------------------------------------------------===//

def VADD : FR<0x62, 0x00, (outs VR:$vd), (ins VR:$vs1, VR:$vs2),
              "VADD $vd, $vs1, $vs2",
              [(set VR:$vd, (add VR:$vs1, VR:$vs2))]>;

def VMUL : FR<0x63, 0x00, (outs VR:$vd), (ins VR:$vs1, VR:$vs2),
              "VMUL $vd, $vs1, $vs2",
              [(set VR:$vd, (mul VR:$vs1, VR:$vs2))]>;

def VFMA : FR<0x64, 0x00, (outs VR:$vd), (ins VR:$vd_in, VR:$vs1, VR:$vs2),
              "VFMA $vd, $vs1, $vs2",
              [(set VR:$vd, (fma VR:$vs1, VR:$vs2, VR:$vd_in))]> {
  let Constraints = "$vd = $vd_in"; // Ties the input accumulator to the output
}
