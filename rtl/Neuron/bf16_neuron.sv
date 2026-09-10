module bf16_neuron #(
    parameter int INP_NUM = 32
)(
    input logic [15:0] inp [INP_NUM],
    input logic [15:0] weight [INP_NUM],
    input logic [15:0] bias,
    output logic [15:0] result
);

logic [31:0] inp_fp32 [INP_NUM];
logic [31:0] weight_fp32 [INP_NUM];
logic [31:0] products [INP_NUM];
logic [31:0] acc_sum;
logic [31:0] bf16_to_fp32_bias;
logic [31:0] fp32_result;

genvar i;

generate

    // Multipliers and bf16 to fp32 modules generation

    for (i=0; i < INP_NUM; i++) begin : MUL_GEN

        bf16_to_fp32 inp_conv (
            .inp(inp[i]),
            .out(inp_fp32[i])
        );

        bf16_to_fp32 weight_conv (
            .inp(weight[i]),
            .out(weight_fp32[i])
        );        

        fp_mult my_fp_mult (
            .a(inp_fp32[i]),
            .b(weight_fp32[i]),
            .z(products[i]),
            .status() // intentionally left unconnected
        ); 
    end
endgenerate

// Adder tree instantiaion

fp32_adder_tree #(
    .INP_NUM(INP_NUM)
) my_fp32_adder_tree (
    .inp(products),
    .out(acc_sum)
);

bf16_to_fp32 my_bf16_to_fp32 (
            .inp(bias),
            .out(bf16_to_fp32_bias)
        );

// Bias addition to accumulated sum

fp32_adder my_fp32_adder (
    .a(acc_sum),
    .b(bf16_to_fp32_bias),
    .result(fp32_result)
);

fp32_to_bf16 my_fp32_to_bf16 (
    .inp(fp32_result),
    .out(result)
);

endmodule