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
