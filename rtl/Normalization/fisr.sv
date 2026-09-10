module fisr (
    input logic [31:0] inp,
    output logic [31:0] result
);

localparam logic [31:0] MAGIC = 32'h5f3759df;
localparam logic [31:0] FP32_0_5 = 32'h3f000000; 
localparam logic [31:0] FP32_1_5 = 32'h3fc00000;

// Initial approx
logic [31:0] shifted;
logic [31:0] y0;

// Newton iteration signals
logic [31:0] x_half;
logic [31:0] y_sq;
logic [31:0] x_half_y_sq;
logic [31:0] neg_x_half_y_sq;
logic [31:0] corr_term;

assign shifted = inp >> 1;

assign y0 = MAGIC - shifted;

fp_mult mul_half (
    .a(inp),
    .b(FP32_0_5),
    .z(x_half),
    .status() // intentionally left unconnected
);

fp_mult mul_sq (
    .a(y0),
    .b(y0),
    .z(y_sq),
    .status() // intentionally left unconnected
);

fp_mult mul_x_half_y_sq (
    .a(x_half),
    .b(y_sq),
    .z(x_half_y_sq),
    .status() // intentionally left unconnected
);

assign neg_x_half_y_sq = {~x_half_y_sq[31],x_half_y_sq[30:0]};

fp32_adder my_fp32_adder (
    .a(FP32_1_5),
    .b(neg_x_half_y_sq),
    .result(corr_term)
);

fp_mult mul_res (
    .a(y0),
    .b(corr_term),
    .z(result),
    .status() // intentionally left unconnected
);

endmodule