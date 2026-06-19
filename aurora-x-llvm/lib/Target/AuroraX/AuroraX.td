//===-- AuroraX.td - Describe the AuroraX Target Machine ---*- tablegen -*-===//
//
// This is the top level entry point for the AURORA-X target.
//
//===----------------------------------------------------------------------===//

// Include LLVM core target descriptions
include "llvm/Target/Target.td"

// Include AURORA-X specific definitions
include "AuroraXRegisterInfo.td"
include "AuroraXInstrInfo.td"
include "AuroraXCallingConv.td"

//===----------------------------------------------------------------------===//
// Target Machine Definition
//===----------------------------------------------------------------------===//

def AuroraXInstrInfo : InstrInfo;

// Define the AURORA-X Target Processor
def : Processor<"aurorax-generic", NoItineraries, []>;

// Define the AURORA-X Target Architecture
def AuroraX : Target {
  let InstructionSet = AuroraXInstrInfo;
}
