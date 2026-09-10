module leading_zero_counter_27 (
    input logic [26:0] inp,
    output logic [4:0] count
);

integer i;

always_comb begin
    count = 5'd27;

    for(i = 26; i >= 0; i--) begin
        if (inp[i]) begin
            count = 5'(26 - i);
            break;
        end
    end
end

endmodule