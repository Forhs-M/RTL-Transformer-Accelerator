module positional_encoder #(
    parameter int D_MODEL = 8,
    parameter int SEQ_LEN = 4,
    localparam int SEQ_LEN_ENC = $clog2(SEQ_LEN) 
)(
    input logic [15:0] inp [D_MODEL],
    input logic [SEQ_LEN_ENC-1:0] row,
    output logic [15:0] sum [D_MODEL] 
);

genvar i; 

logic [15:0] pos_enc [SEQ_LEN][D_MODEL];

`include "pos_enc_assigns.svh"

logic [31:0] inp_fp32 [D_MODEL];
logic [31:0] pos_enc_fp32 [D_MODEL];
logic [31:0] sum_fp32 [D_MODEL];

generate

    for(i = 0; i < D_MODEL; i++) begin : ADDERS_GEN

        bf16_to_fp32 inp_conv (
            .inp(inp[i]),
            .out(inp_fp32[i])
        );

        bf16_to_fp32 pos_enc_conv (
            .inp(pos_enc[row][i]),
            .out(pos_enc_fp32[i])
        ); 

        fp32_adder my_fp32_adder (
            .a(inp_fp32[i]),
            .b(pos_enc_fp32[i]),
            .result(sum_fp32[i])
        );

        fp32_to_bf16 sum_round (
            .inp(sum_fp32[i]),
            .out(sum[i])
        );
    end
endgenerate

endmodule