module round_mult (output logic [24:0] result,
                     output logic inexact,
                     output logic [9:0] post_round_exponent,
                     input logic [9:0] pre_round_exponent,
                     input logic [23:0] mantissa,
                     input logic guard,
                     input logic sticky,
                     input logic sign);

logic [24:0] pre_round_mantissa;
    
always_comb begin
    inexact = guard | sticky;
end

// RNE rounding

always_comb begin
    if (inexact == 1'b1) begin
        if(guard == 1'b1 && (sticky||mantissa[0]))
            pre_round_mantissa = {1'b0, mantissa} + 1'b1;
        else
            pre_round_mantissa = {1'b0, mantissa};
    end
    else
        pre_round_mantissa = {1'b0, mantissa};    
end

always_comb begin
    if (pre_round_mantissa[24] == 1) begin
        result = {1'b1, pre_round_mantissa[24:1]};
        post_round_exponent =  pre_round_exponent + 1;
    end
    else begin
        result = pre_round_mantissa;
        post_round_exponent = pre_round_exponent;
    end
end

endmodule
