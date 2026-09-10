// Division by 2^LOGED_DIVISOR
// Denormal results flushed to 0 

module pow_of_2_div #(
    parameter int LOG2_DIVISOR = 3 
)(
    input logic [31:0] inp,
    output logic [31:0] result
);

logic sign;
logic [7:0] exp;
logic [22:0] mant;

assign sign = inp[31];
assign exp = inp[30:23];
assign mant = inp[22:0];

always_comb begin
    if (exp == 8'hff) begin
        result = inp;
    end
    else if (exp > LOG2_DIVISOR) begin
        result = {sign, exp - LOG2_DIVISOR[7:0], mant};
    end
    else begin
        result = {sign, 31'b0};
    end
end

endmodule
