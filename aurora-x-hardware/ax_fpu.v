module ax_fpu (
    input  [63:0] A,
    input  [63:0] B,
    input         Fpu_ALU_Op, // 0: ADD, 1: MUL
    output [63:0] Result
);

    // Extraction
    wire sign_a = A[63];
    wire [10:0] exp_a = A[62:52];
    wire [52:0] mant_a = (|exp_a) ? {1'b1, A[51:0]} : 53'd0;

    wire sign_b = B[63];
    wire [10:0] exp_b = B[62:52];
    wire [52:0] mant_b = (|exp_b) ? {1'b1, B[51:0]} : 53'd0;

    // ==========================================
    // FLOATING POINT ADDITION (Simplified)
    // ==========================================
    wire a_larger = (exp_a > exp_b) || (exp_a == exp_b && mant_a >= mant_b);
    wire [10:0] exp_large = a_larger ? exp_a : exp_b;
    wire [10:0] exp_small = a_larger ? exp_b : exp_a;
    wire [52:0] mant_large = a_larger ? mant_a : mant_b;
    wire [52:0] mant_small = a_larger ? mant_b : mant_a;
    wire sign_large = a_larger ? sign_a : sign_b;
    wire sign_small = a_larger ? sign_b : sign_a;

    wire [10:0] exp_diff = exp_large - exp_small;
    wire [52:0] mant_small_shifted = (exp_diff > 53) ? 53'd0 : (mant_small >> exp_diff);

    wire signs_equal = (sign_large == sign_small);
    wire [53:0] mant_sum = signs_equal ? (mant_large + mant_small_shifted) : (mant_large - mant_small_shifted);

    // Normalize ADD result
    wire [10:0] exp_add_norm;
    wire [51:0] mant_add_norm;
    wire sign_add = sign_large;

    // A very basic normalizer (checks top 2 bits)
    assign exp_add_norm = (mant_sum[53]) ? (exp_large + 1) : 
                          (mant_sum[52]) ? exp_large : 
                          (mant_sum[51]) ? (exp_large - 1) :
                          (mant_sum[50]) ? (exp_large - 2) : exp_large; // simplified

    assign mant_add_norm = (mant_sum[53]) ? mant_sum[52:1] :
                           (mant_sum[52]) ? mant_sum[51:0] :
                           (mant_sum[51]) ? {mant_sum[50:0], 1'b0} :
                           (mant_sum[50]) ? {mant_sum[49:0], 2'b00} : mant_sum[51:0];

    wire [63:0] add_result = (mant_sum == 0) ? 64'd0 : {sign_add, exp_add_norm, mant_add_norm};

    // ==========================================
    // FLOATING POINT MULTIPLICATION (Simplified)
    // ==========================================
    wire sign_mul = sign_a ^ sign_b;
    wire [11:0] exp_mul_temp = exp_a + exp_b - 1023;
    
    // 53x53 multiplier -> 106 bits
    // For Verilog synthesis, we do a raw multiply (this will infer hardware multipliers)
    wire [105:0] mant_mul = mant_a * mant_b;
    
    // Normalize MUL result
    // Normalized mantissa format has MSB at bit 105 or 104
    wire mul_norm_shift = mant_mul[105];
    wire [10:0] exp_mul = mul_norm_shift ? (exp_mul_temp + 1) : exp_mul_temp;
    wire [51:0] mant_mul_norm = mul_norm_shift ? mant_mul[104:53] : mant_mul[103:52];
    
    wire [63:0] mul_result = (mant_a == 0 || mant_b == 0) ? 64'd0 : {sign_mul, exp_mul, mant_mul_norm};

    // ==========================================
    // RESULT MUX
    // ==========================================
    assign Result = Fpu_ALU_Op ? mul_result : add_result;

endmodule
