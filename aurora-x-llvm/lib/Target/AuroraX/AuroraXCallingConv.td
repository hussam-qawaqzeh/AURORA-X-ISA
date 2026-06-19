//===-- AuroraXCallingConv.td - Calling Conventions --------*- tablegen -*-===//
//
// This describes the calling conventions for AURORA-X architecture.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// AURORA-X C Calling Convention
//===----------------------------------------------------------------------===//
def CC_AuroraX : CallingConv<[
  // Promote i8/i16/i32 arguments to i64.
  CCIfType<[i8, i16, i32], CCPromoteToType<i64>>,

  // Pass by value if the type is i64.
  // The first 8 arguments are passed in registers R1 to R8.
  CCIfType<[i64], CCAssignToReg<[R1, R2, R3, R4, R5, R6, R7, R8]>>,

  // Integer values that get over the register limit are passed on the stack,
  // aligned to 8 bytes.
  CCIfType<[i64], CCAssignToStack<8, 8>>
]>;

//===----------------------------------------------------------------------===//
// AURORA-X C Return Value Calling Convention
//===----------------------------------------------------------------------===//
def RetCC_AuroraX : CallingConv<[
  // Promote i8/i16/i32 return values to i64.
  CCIfType<[i8, i16, i32], CCPromoteToType<i64>>,

  // Return values are passed in R1 and R2.
  CCIfType<[i64], CCAssignToReg<[R1, R2]>>
]>;

//===----------------------------------------------------------------------===//
// Callee-saved Registers
//===----------------------------------------------------------------------===//
def CSR_AuroraX : CalleeSavedRegs<(add 
  R19, R20, R21, R22, R23, R24, R25, R26, R27, R28, R29, R31
)>;
