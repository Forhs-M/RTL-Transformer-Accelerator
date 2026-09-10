module normalizer #(
    parameter int INP_NUM = 8 // INP_NUM MUST be power of 2
)(
    input logic [15:0] inp [INP_NUM],
    input logic [15:0] alpha,
    input logic [15:0] bias,
    input logic [15:0] epsilon,
    output logic [31:0] result [INP_NUM]
);

localparam int INP_NUM_LOG_2 = $clog2(INP_NUM);

logic [31:0] inp_fp32 [INP_NUM];
logic [31:0] inp_sum;
logic [31:0] mean;
logic [31:0] neg_mean;
logic [31:0] inp_minus_mean [INP_NUM];
logic [31:0] inp_minus_mean_squared [INP_NUM];
logic [31:0] squares_sum;
logic [31:0] variance;
logic [31:0] epsilon_fp32;
logic [31:0] var_plus_epsilon;
logic [31:0] inv_sqrt_var_plus_epsilon;
logic [31:0] alpha_fp32;
logic [31:0] bias_fp32;
logic [31:0] norm_after_alpha [INP_NUM];
logic [31:0] norm_after_inv_sqrt [INP_NUM];

genvar i;

generate

    for(i=0; i<INP_NUM; i++) begin : bf16_to_fp32

        bf16_to_fp32 inp_conv (
            .inp(inp[i]),
            .out(inp_fp32[i])
        );
    end
endgenerate

fp32_adder_tree #(
    .INP_NUM(INP_NUM)
) my_fp32_adder_tree_1 (
    .inp(inp_fp32),
    .out(inp_sum)
);

pow_of_2_div #(
    .LOG2_DIVISOR(INP_NUM_LOG_2)
) pow_of_2_div_1 (
    .inp(inp_sum),
    .result(mean)
);

assign neg_mean = {~mean[31],mean[30:0]};

generate 

    for(i=0; i<INP_NUM; i++) begin : ADD_GEN
        
        fp32_adder my_fp32_adder (
            .a(inp_fp32[i]),
            .b(neg_mean),
            .result(inp_minus_mean[i])
        );
    end

    for(i=0; i<INP_NUM; i++) begin : MUL_GEN_1
        fp_mult my_fp_mult (
            .a(inp_minus_mean[i]),
            .b(inp_minus_mean[i]),
            .z(inp_minus_mean_squared[i]),
            .status() // intentionally left unconnected
        );
    end
endgenerate

fp32_adder_tree #(
    .INP_NUM(INP_NUM)
) my_fp32_adder_tree_2 (
    .inp(inp_minus_mean_squared),
    .out(squares_sum)
);

pow_of_2_div #(
    .LOG2_DIVISOR(INP_NUM_LOG_2)
) pow_of_2_div_2 (
    .inp(squares_sum),
    .result(variance)
);

bf16_to_fp32 epsilon_conv (
    .inp(epsilon),
    .out(epsilon_fp32)
);

fp32_adder fp32_adder_var_plus_epsilon (
    .a(variance),
    .b(epsilon_fp32),
    .result(var_plus_epsilon)
);

fisr my_fisr (
    .inp(var_plus_epsilon),
    .result(inv_sqrt_var_plus_epsilon)
);

bf16_to_fp32 alpha_conv (
    .inp(alpha),
    .out(alpha_fp32)
);

bf16_to_fp32 bias_conv (
    .inp(bias),
    .out(bias_fp32)
);

generate 

    for(i=0; i<INP_NUM; i++) begin : MUL_GEN_2
        fp_mult fp_mult_alpha (
            .a(inp_minus_mean[i]),
            .b(alpha_fp32),
            .z(norm_after_alpha[i]),
            .status() // intentionally left unconnected
        );

        fp_mult fp_mult_out (
            .a(norm_after_alpha[i]),
            .b(inv_sqrt_var_plus_epsilon),
            .z(norm_after_inv_sqrt[i]),
            .status() // intentionally left unconnected
        );
    end

    for(i=0; i<INP_NUM; i++) begin : ADD_GEN_2
        fp32_adder bias_addition (
            .a(norm_after_inv_sqrt[i]),
            .b(bias_fp32),
            .result(result[i])
        );
    end
endgenerate

endmodule