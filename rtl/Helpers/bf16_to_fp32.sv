// bf16_to_fp32: Converts bf16 to fp32.

module bf16_to_fp32 (
    input logic [15:0] inp,
    output logic [31:0] out
);

assign out = {inp, 16'b0};

endmodule