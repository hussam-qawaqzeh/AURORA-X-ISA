// ============================================================================
// AURORA-X SoC Configuration Header
// ============================================================================
// Centralized configuration file to manage core counts and hardware features.
// Modify this file to scale the processor up or down.
// ============================================================================

`ifndef AURORA_CONFIG_VH
`define AURORA_CONFIG_VH

// ----------------------------------------------------------------------------
// Core Counts Configuration
// ----------------------------------------------------------------------------
// Define the number of each type of core in the SoC.
// Total cores in the SoC = NUM_P_CORES + NUM_E_CORES + NUM_AG_CORES
// CAUTION: The ax_bus_scalable arbitration logic dynamically scales based on this.

`define NUM_P_CORES  1   // Performance Cores (Full Pipeline, No Vector SIMT)
`define NUM_E_CORES  1   // Efficiency Cores (Simplified Pipeline, Low Power)
`define NUM_AG_CORES 0   // AG Cores (AI & Graphics, Full Pipeline + 2048-bit Vector SIMT + Masking)

// Total cores (Helper macro - do not edit manually if possible, but Verilog doesn't 
// allow complex macro math in some contexts, so we define it manually for array sizes)
`define TOTAL_CORES 2

// ----------------------------------------------------------------------------
// Clock Frequencies (Hardware Dividers)
// ----------------------------------------------------------------------------
// 00 = Full Speed (Clk/1)
// 01 = Half Speed (Clk/2)
// 10 = Quarter Speed (Clk/4)
// 11 = Eighth Speed (Clk/8)
`define FREQ_DIV_P_CORE  2'b00   // P-Cores run at Max Speed
`define FREQ_DIV_E_CORE  2'b01   // E-Cores run at Half Speed (Power Saving)
`define FREQ_DIV_AG_CORE 2'b10   // AG-Cores run at Quarter Speed (Maximum Thermal/Logic Safety at Boot)

// ----------------------------------------------------------------------------
// AG-Core Mode (GPGPU vs AI-Only)
// ----------------------------------------------------------------------------
// Uncomment the line below to build the AG-Cores as purely AI accelerators (NPUs).
// This drops the Vector Masking and Permutation hardware to save massive silicon area.
// `define AG_CORE_MODE_AI_ONLY 1

// ----------------------------------------------------------------------------
// Memory Subsystem
// ----------------------------------------------------------------------------
`define ENABLE_L3_CACHE 1         // 1 to enable L3 cache, 0 to disable
`define ENABLE_3D_VCACHE 0        // 1 to use 3D V-Cache sizes (requires L3 enabled)
`define ENABLE_MMU 1              // 1 to enable Memory Management Unit (Virtual Memory)

`define L3_CACHE_SIZE_BYTES (`ENABLE_3D_VCACHE ? 65536 : 512)

`endif // AURORA_CONFIG_VH
