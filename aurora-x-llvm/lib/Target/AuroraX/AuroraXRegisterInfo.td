//===-- AuroraXRegisterInfo.td - AuroraX Register defs ----*- tablegen -*-===//
//
// Defines the AURORA-X register file for LLVM.
//
//===----------------------------------------------------------------------===//

//--- General Purpose Registers (64-bit) ---
class AuroraXGPRReg<bits<5> Enc, string n> : Register<n> {
  let HWEncoding{4-0} = Enc;
  let Namespace = "AuroraX";
}

// Define the 32 General Purpose Registers (R0 to R31)
foreach i = 0-31 in {
  def R#i : AuroraXGPRReg<i, "R"#i>;
}

// Define the GPR Register Class (i64 type)
def GPR : RegisterClass<"AuroraX", [i64], 64, (add
  // Return values and arguments
  R1, R2, R3, R4, R5, R6, R7, R8,
  // Temporaries
  R9, R10, R11, R12, R13, R14, R15, R16, R17, R18,
  // Callee Saved
  R19, R20, R21, R22, R23, R24, R25, R26, R27, R28, R29,
  // Special Purpose
  R30, // Stack Pointer (SP)
  R31, // Return Address (RA)
  R0   // Constant Zero (Hardware wired to 0)
)>;

//--- Vector Registers (2048-bit scalable) ---
class AuroraXVRReg<bits<5> Enc, string n> : Register<n> {
  let HWEncoding{4-0} = Enc;
  let Namespace = "AuroraX";
}

// Define the 32 Vector Registers (V0 to V31)
foreach i = 0-31 in {
  def V#i : AuroraXVRReg<i, "V"#i>;
}

// Define Vector Register Class (mapped to scalable vector types)
def VR : RegisterClass<"AuroraX", [vXf32, vXi32], 2048, (add
  (sequence "V%u", 0, 31)
)>;
