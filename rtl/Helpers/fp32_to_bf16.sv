// fp32_to_bf16: Converts FP32 to bf16 based on RNE rounding.
// No NaN exception handling, probably not needed.

module fp32_to_bf16 (
    input logic [31:0] inp,
    output logic [15:0] out
);

logic sticky, round;

assign sticky = |inp[14:0];
assign round = inp[15] & (sticky | inp[16]);

assign out = inp[31:16] + round;

endmodule

