module normalize_mult (output logic [9:0] exponent,
                       output logic [22:0] mantissa,
                       output logic guard,
                       output logic sticky,
                       input logic [47:0] mult_res, 
                       input logic [9:0] addition);

// Wires that are inside of the module (not input/output)

logic [9:0] poss_exponent;
logic [22:0] poss_mantissa_1;
logic [22:0] poss_mantissa_0;
logic poss_guard_bit_1;
logic poss_guard_bit_0;
logic [22:0] poss_sticky_bit_1;
logic [21:0] poss_sticky_bit_0;

assign poss_exponent = addition + 1;
assign poss_mantissa_0 = mult_res[45:23];   
assign poss_mantissa_1 = mult_res[46:24];   
assign poss_guard_bit_0 = mult_res[22];
assign poss_guard_bit_1 = mult_res[23];
assign poss_sticky_bit_0 = mult_res[21:0];
assign poss_sticky_bit_1 = mult_res[22:0];

// MUXs

always_comb begin
    if(mult_res[47] == 1) 
        exponent = poss_exponent;
    else
        exponent = addition;
end

// Normalized mantissa

always_comb begin
    if(mult_res[47] == 1)
        mantissa = poss_mantissa_1;
    else
        mantissa = poss_mantissa_0;    
end

// Guard bit

always_comb begin
    if(mult_res[47] == 1)
        guard = poss_guard_bit_1;
    else
        guard = poss_guard_bit_0;
end

// Sticky bit

always_comb begin
    if(mult_res[47] == 1)
        sticky = |poss_sticky_bit_1;
    else
        sticky = |poss_sticky_bit_0;
end

endmodule