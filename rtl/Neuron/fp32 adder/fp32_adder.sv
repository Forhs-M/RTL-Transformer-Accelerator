module fp32_adder (
    input logic [31:0] a,
    input logic [31:0] b,
    output logic [31:0] result 
);

logic a_sign, b_sign;
logic l_sign;
logic [7:0] a_exp, b_exp;
logic [7:0] l_exp;
logic [22:0] a_mant, b_mant;

logic signed [8:0] shift;
logic [7:0] shift_amt;
logic [26:0] shifted; // [26] hidden, [25:3] mantissa, [2] guard, round [1], [0] sticky
logic [26:0] aligned_mantissa; // [26] hidden, [25:3] mantissa, [2] guard, round [1], [0] sticky
logic sticky_align; 

assign a_sign = a[31];
assign b_sign = b[31];
assign a_exp = a[30:23];
assign b_exp = b[30:23];

logic a_is_0, b_is_0, a_is_inf, b_is_inf;

// Flushing denormals to 0 and trating NaNs as infinities

always_comb begin : EXCEPTION_PREHANDLING
    a_is_0 = 1'b0;
    b_is_0 = 1'b0;
    a_is_inf = 1'b0;
    b_is_inf = 1'b0;
    a_mant = a[22:0];
    b_mant = b[22:0];

    if (a_exp == 8'b0) begin
        a_mant = 23'b0;
        a_is_0 = 1'b1;
    end
    if (b_exp == 8'b0) begin
        b_mant = 23'b0;
        b_is_0 = 1'b1;
    end
    if (a_exp == 8'b11111111) begin
        a_mant = 23'b0;
        a_is_inf = 1'b1;
    end
    if (b_exp == 8'b11111111) begin
        b_mant = 23'b0;
        b_is_inf = 1'b1;
    end
end

logic operation; // 0: addition 1: subtraction

assign operation = a_sign ^ b_sign;

assign shift = $signed({1'b0, a_exp}) - $signed({1'b0, b_exp}); 

logic a_is_larger; // 1: |a| > |b|, 0: |a| < |b|
logic same_exp; // 1: a_exp = b_exp
logic opp_nums; // 1: a = -b, 0: a != -b 

always_comb begin : LARGER_NUM
    opp_nums = 1'b0;
    if (shift > 0) begin
        a_is_larger = 1'b1;
        l_exp = a_exp;
        same_exp = 1'b0;
        l_sign = a_sign;    
    end
    else if(shift == 0) begin
        same_exp = 1'b1;
        l_exp = a_exp;
        if(a_mant > b_mant) begin
            a_is_larger = 1'b1;
            l_sign = a_sign;
        end
        else if (a_mant < b_mant) begin
            a_is_larger = 1'b0;
            l_sign = b_sign;        
        end
        else begin
            a_is_larger = 1'b0;
            l_sign = b_sign;
            opp_nums = operation;
        end
    end
    else begin
        a_is_larger = 1'b0;
        l_exp = b_exp;
        same_exp = 1'b0;
        l_sign = b_sign;
    end
end

logic [26:0] small_ext;
logic [26:0] mask;

always_comb begin : MANTISSA_ALIGNEMENT
    if (a_is_larger == 1'b1) begin
        small_ext = {1'b1,b_mant,3'b0};
        shift_amt = (shift > 27) ? 8'd27 : shift[7:0];
        if (same_exp == 1'b1) begin
            shifted = small_ext;
            sticky_align = 1'b0;
        end
        else if (shift_amt == 27) begin
            shifted = 27'b0;
            sticky_align = |small_ext;
        end
        else begin
            shifted = small_ext >> shift_amt;
            mask = (27'b1 << shift_amt) - 27'b1;
            sticky_align = |(small_ext & mask);
        end        
        aligned_mantissa = {shifted[26:1],shifted[0] | sticky_align};
    end 
    else begin
        small_ext = {1'b1,a_mant,3'b0};
        shift_amt = ((-shift) > 27) ? 8'd27 : (-shift);
        if (same_exp == 1'b1) begin
            shifted = small_ext;
            sticky_align = 1'b0;
        end
        else if (shift_amt == 27) begin
            shifted = 27'b0;
            sticky_align = |small_ext;
        end
        else begin
            shifted = small_ext >> shift_amt;
            mask = (27'b1 << shift_amt) - 27'b1;
            sticky_align = |(small_ext & mask);
        end        
        aligned_mantissa = {shifted[26:1],shifted[0] | sticky_align};
    end
end

logic [27:0] op_mantissa; // op_mantissa: mantissa calculated after addition or subtraction

always_comb begin : OPERATION
    if (operation == 0) begin
        if (a_is_larger) begin
            op_mantissa = {2'b01,a_mant,3'b0} + {1'b0,aligned_mantissa};
        end
        else begin
            op_mantissa = {2'b01,b_mant,3'b0} + {1'b0,aligned_mantissa};
        end          
    end
    else begin
        if (same_exp == 1'b1) begin
            if (a_is_larger) begin
                op_mantissa = {2'b01,a_mant,3'b0} - {2'b01,b_mant,3'b0};
        end
            else begin
                op_mantissa = {2'b01,b_mant,3'b0} - {2'b01,a_mant,3'b0};
            end
        end
        else if (a_is_larger == 1'b1) begin
            op_mantissa = {2'b01,a_mant,3'b0} - {1'b0,aligned_mantissa}; 
        end
        else begin
            op_mantissa = {2'b01,b_mant,3'b0} - {1'b0,aligned_mantissa}; 
        end
    end
end

logic [26:0] norm_mantissa;
logic [7:0] norm_exp;
logic [4:0] count;

// Leading zero counter instantiation

leading_zero_counter_27 my_leading_zero_counter_27(
    .inp(op_mantissa[26:0]),
    .count(count)
);

logic underflow;

always_comb begin : NORMALIZATION
    underflow = 1'b0;
    if (operation == 0) begin
        if (op_mantissa[27] == 1) begin
            norm_mantissa = op_mantissa[27:1];
            norm_mantissa[0] = norm_mantissa[0] | op_mantissa[0];
            norm_exp = l_exp + 8'b1;
        end
        else begin
            norm_mantissa = op_mantissa[26:0];
            norm_exp = l_exp;
        end
    end
    else begin
        if (op_mantissa == 28'b0) begin
            norm_mantissa = 27'b0;
            norm_exp = 8'b0;
            underflow = 1'b1;
        end
        else if (op_mantissa[26] == 0) begin
            if (count >= l_exp) begin
                norm_mantissa = 27'b0;
                norm_exp = 8'b0;
                underflow = 1'b1;
            end
            else begin
            norm_mantissa = op_mantissa[26:0] << count;
            norm_exp = l_exp - count;
            end
        end
        else begin
            norm_mantissa = op_mantissa[26:0];
            norm_exp = l_exp;
        end
    end
end

logic guard, round, sticky;

assign guard = norm_mantissa[2];
assign round = norm_mantissa[1];
assign sticky = norm_mantissa[0];

logic [27:0] pre_rnd_mantissa; 
logic [22:0] post_round_mantissa;
logic [7:0] post_round_exponent;

always_comb begin : RNE_ROUNDING
    if (guard == 1'b1 && (round || sticky || norm_mantissa[3])) begin
        pre_rnd_mantissa = {1'b0,norm_mantissa} + 28'b1000;
    end
    else begin
        pre_rnd_mantissa = {1'b0,norm_mantissa};
    end
    if(pre_rnd_mantissa[27] == 1'b1) begin
        post_round_mantissa = pre_rnd_mantissa[26:4];
        post_round_exponent = norm_exp + 8'b1;
    end
    else begin
        post_round_mantissa = pre_rnd_mantissa[25:3];
        post_round_exponent = norm_exp;
    end
end

logic [31:0] exception_res;

always_comb begin: EXCEPTION_HANDLING
    if (a_is_inf == 1'b1) begin
        exception_res = {a_sign,8'b11111111,23'b0};
    end
    else if (b_is_inf == 1'b1) begin
        exception_res = {b_sign,8'b11111111,23'b0};
    end
    else if (a_is_0 == 1'b1) begin
        if (b_is_0 == 1'b1) begin
            exception_res = 32'b0;
        end
        else begin
            exception_res = {b_sign,b_exp,b_mant};
        end
    end
    else if (b_is_0 == 1'b1) begin
        if (a_is_0 == 1'b1) begin
            exception_res = 32'b0;
        end
        else begin
            exception_res = {a_sign,a_exp,a_mant};
        end
    end
    else if (opp_nums == 1'b1) begin
        exception_res = 32'b0;
    end
    else if (post_round_exponent == 8'b11111111) begin
        exception_res = {l_sign,8'b11111111,23'b0};
    end
    else if (underflow == 1'b1) begin
        exception_res = 32'b0;
    end
    else begin
        exception_res = {l_sign,post_round_exponent,post_round_mantissa}; 
    end
end

assign result = exception_res; 

endmodule