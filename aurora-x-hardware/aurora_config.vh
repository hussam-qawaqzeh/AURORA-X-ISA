`ifndef AURORA_CONFIG_VH
`define AURORA_CONFIG_VH

// ============================================================================
// AURORA-X Scalable Heterogeneous SoC Configuration
// ============================================================================

// ----------------------------------------------------------------------------
// Core Counts Configuration
// ----------------------------------------------------------------------------
// Define the number of each type of core in the SoC.
// Total cores in the SoC = NUM_P_CORES + NUM_E_CORES + NUM_AI_CORES
// CAUTION: The ax_bus_scalable arbitration logic dynamically scales based on this.

`define NUM_P_CORES  3   // Performance Cores (Full Pipeline, No Vector SIMT)
`define NUM_E_CORES  3   // Efficiency Cores (Simplified Pipeline, Low Power)
`define NUM_AI_CORES 3   // AI / GPU Cores (Full Pipeline + 2048-bit Vector SIMT)

// Total cores (Helper macro - do not edit manually if possible, but Verilog doesn't 
// allow complex macro math in some contexts, so we define it manually for array sizes)
`define TOTAL_CORES 9

// ----------------------------------------------------------------------------
// Cache Architecture Configuration
// ----------------------------------------------------------------------------
`define L1_CACHE_SIZE 32768   // 32 KB per core
`define L2_CACHE_SIZE 1048576 // 1 MB shared (or per cluster, depending on topology)

// ----------------------------------------------------------------------------
// L3 & 3D V-Cache Technology
// ----------------------------------------------------------------------------
`define ENABLE_L3_CACHE  1    // 1 to instantiate L3 Cache, 0 to bypass L3
`define ENABLE_3D_VCACHE 1    // 1 = 100MB+ Massive LLC, 0 = Max 20MB standard LLC

// L3 Cache Size calculation based on 3D V-Cache flag
`ifdef ENABLE_3D_VCACHE
    `define L3_CACHE_SIZE_BYTES 104857600 // 100 MB (Note: Reduce for faster iverilog compilation)
`else
    `define L3_CACHE_SIZE_BYTES 20971520  // 20 MB
`endif

`endif // AURORA_CONFIG_VH
