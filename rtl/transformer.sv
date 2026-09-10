module transformer #(
    parameter int N_S = 64,
    parameter int SEQ_LEN = 4,
    parameter int D_MODEL = 16,
    parameter logic [31:0] INVERSE_SQRT_D_MODEL = 32'h3EB504F3,
    parameter int INT_WIDTH = 8,
    parameter int FRAC_WIDTH = 8,
    parameter int LUT_ENTRIES_NUM = 32, 
    parameter int D_FF = 32,
    parameter int OUT_ENTRIES = 1024,
    localparam int SEQ_LEN_ENC = $clog2(SEQ_LEN),
    localparam int D_MODEL_ENC = $clog2(D_MODEL),
    localparam int D_FF_ENC = $clog2(D_FF),
    localparam int NUM_WIDTH = INT_WIDTH + FRAC_WIDTH,
    localparam int FLAT_ENTRIES_NUM = SEQ_LEN*D_MODEL,
    localparam int OUT_ENTRIES_ENC = $clog2(OUT_ENTRIES)
)(
    input logic [15:0] sensor_values [N_S],
    input logic [15:0] weights [N_S],
    input logic [15:0] bias,
    input logic clk,
    input logic rst,
    input logic ready,
    output logic valid_out,
    output logic [15:0] result_entry,
    output logic done
);

typedef enum logic [4:0] {
    IDLE,
    FC_1,
    POS_ENC,
    NORMALIZE_1,
    Q_CALC,
    K_CALC,
    V_CALC,
    QK_PROD,
    SOFTMAX,
    V_PROD,
    O_PROD,
    NORM_ADD_1,
    NORMALIZE_2,
    FC_2,
    FC_3,
    NORM_ADD_2,
    FINAL_NORMALIZE,
    FC_4,
    FC_4_FINAL,
    DONE
} state_t;

state_t c_state, n_state;

logic [1:0] fc_inp_sel;
logic [15:0] fc_inp [N_S];
logic [15:0] neuron_weight [N_S];
logic [15:0] neuron_bias;
logic [15:0] fc_res;

logic [1:0] norm_inp_sel;

logic [15:0] norm_inp [D_MODEL];
logic [15:0] norm_res [D_MODEL];

logic [31:0] norm_res_fp32 [D_MODEL];

logic norm_add_sel;
logic [15:0] norm_add_inp_1 [D_MODEL];
logic [15:0] norm_add_inp_2 [D_MODEL];

logic [31:0] norm_add_inp_1_fp32 [D_MODEL];
logic [31:0] norm_add_inp_2_fp32 [D_MODEL];

logic [15:0] norm_add_res [D_MODEL];

logic [15:0] fc_1_res;

logic [D_MODEL_ENC-1:0] c_d_model_fc_1;
logic [SEQ_LEN_ENC-1:0] c_seq_len_fc_1;

logic [15:0] fc_1_res_reg [SEQ_LEN][D_MODEL];

logic [15:0] pos_enc_res [D_MODEL];

logic [SEQ_LEN_ENC-1:0] c_seq_len_pos_enc;
logic [15:0] pos_enc_res_reg [SEQ_LEN][D_MODEL];

logic [31:0] normalize_1_res_fp32 [D_MODEL];
logic [15:0] normalize_1_res [D_MODEL];
logic [SEQ_LEN_ENC-1:0] c_normalize_1_row;

logic [15:0] normalize_1_res_reg [SEQ_LEN][D_MODEL];

logic [D_MODEL_ENC-1:0] c_q_k_v_col;
logic [SEQ_LEN_ENC-1:0] c_attn_row;

logic [15:0] q_col_res_reg [SEQ_LEN][D_MODEL];

logic [15:0] k_col_res_reg [SEQ_LEN][D_MODEL];

logic [15:0] v_trans_col_res_reg [D_MODEL][SEQ_LEN];

logic [SEQ_LEN_ENC-1:0] c_qk_col;

logic [31:0] qk_res_fp32;

logic [31:0] qk_res_scaled;
logic [15:0] qk_res_scaled_bf16;

logic [NUM_WIDTH:0] qk_res_reg [SEQ_LEN][SEQ_LEN];

logic [NUM_WIDTH:0] qk_res_scaled_fixed_point;

logic [SEQ_LEN_ENC-1:0] c_softmax_row;

logic [15:0] softmax_res_reg [SEQ_LEN][SEQ_LEN];

logic [FRAC_WIDTH:0] softmax_res [SEQ_LEN];

logic [15:0] softmax_res_bf16 [SEQ_LEN];

logic [D_MODEL_ENC-1:0] c_v_prod_col;

logic [15:0] v_prod_res_reg [SEQ_LEN][D_MODEL]; 

logic [D_MODEL_ENC-1:0] c_o_prod_col;

logic [15:0] o_prod_col_res_reg [SEQ_LEN][D_MODEL]; 

logic [15:0] norm_add_1_res [D_MODEL];
logic [SEQ_LEN_ENC-1:0] c_norm_add_1_row;

logic [15:0] norm_add_1_res_reg [SEQ_LEN][D_MODEL];

logic [31:0] pos_enc_res_reg_fp32 [D_MODEL];
logic [31:0] o_prod_col_res_reg_fp32 [D_MODEL];
logic [31:0] added_1 [D_MODEL];

logic [31:0] normalize_2_res_fp32 [D_MODEL];
logic [31:0] normalize_2_res_reg_fp32 [D_MODEL];
logic [15:0] normalize_2_res [D_MODEL];
logic [SEQ_LEN_ENC-1:0] c_normalize_2_row;

logic [15:0] normalize_2_res_reg [SEQ_LEN][D_MODEL];

logic [D_FF_ENC-1:0] c_d_ff_fc_2;
logic [SEQ_LEN_ENC-1:0] c_seq_len_fc_2;

logic [15:0] fc_2_res_reg [SEQ_LEN][D_FF];

logic [D_MODEL_ENC-1:0] c_d_model_fc_3;
logic [SEQ_LEN_ENC-1:0] c_seq_len_fc_3;

logic [15:0] fc_3_res_reg[SEQ_LEN][D_MODEL];

logic [15:0] norm_add_2_res [D_MODEL];
logic [SEQ_LEN_ENC-1:0] c_norm_add_2_row;

logic [15:0] norm_add_2_res_reg [SEQ_LEN][D_MODEL];

logic [31:0] norm_add_1_res_reg_fp32 [D_MODEL];
logic [31:0] fc_3_res_reg_fp32 [D_MODEL];

logic [31:0] final_normalize_res_fp32 [D_MODEL];
logic [15:0] final_normalize_res [D_MODEL];

logic [SEQ_LEN_ENC-1:0] c_final_normalize_row;

logic [15:0] final_normalize_res_reg [SEQ_LEN][D_MODEL];

logic [15:0] flattened [FLAT_ENTRIES_NUM];

integer l, m;

logic [OUT_ENTRIES_ENC-1:0] c_entry_fc_4;

always_ff @(posedge clk or posedge rst) begin  
    if (rst == 1'b1) begin
        c_state <= IDLE;

        fc_inp_sel <= '0;

        norm_inp_sel <= '0;
        
        norm_add_sel <= 1'b0;

        c_d_model_fc_1 <= '0;
        c_seq_len_fc_1 <= '0;

        c_seq_len_pos_enc <= '0;

        c_normalize_1_row <= '0;

        c_q_k_v_col <= '0;
        c_attn_row <= '0;

        c_qk_col <= '0;

        c_softmax_row <= '0;

        c_v_prod_col <= '0;

        c_o_prod_col <= '0;

        c_norm_add_1_row <= '0;

        c_normalize_2_row <= '0;

        c_d_ff_fc_2 <= '0;
        c_seq_len_fc_2 <= '0;

        c_d_model_fc_3<= '0;
        c_seq_len_fc_3 <= '0;

        c_norm_add_2_row <= '0;

        c_final_normalize_row <= '0;

        c_entry_fc_4 <= '0;

        valid_out <= 1'b0;
        done <= 1'b0;
    end
    else begin
        c_state <= n_state;
        
        valid_out <= 1'b0;
        done <= 1'b0;

        if (c_state == FC_1) begin 
            fc_1_res_reg[c_seq_len_fc_1][c_d_model_fc_1] <= fc_res;
            if (c_d_model_fc_1 == D_MODEL-1) begin
                c_d_model_fc_1 <= '0;
                if (c_seq_len_fc_1 == SEQ_LEN-1) begin
                    c_seq_len_fc_1 <= '0;
                    fc_inp_sel <= 2'b01;
                end
                else begin
                    c_seq_len_fc_1 <= c_seq_len_fc_1 + 1;
                end
            end
            else begin
                c_d_model_fc_1 <= c_d_model_fc_1 + 1;
            end
        end
        else if (c_state == POS_ENC) begin 
            pos_enc_res_reg[c_seq_len_pos_enc] <= pos_enc_res;
            if (c_seq_len_pos_enc == SEQ_LEN-1) begin
                c_seq_len_pos_enc <= '0;
            end
            else begin
                c_seq_len_pos_enc <= c_seq_len_pos_enc + 1;
            end
        end
        else if (c_state == NORMALIZE_1) begin
            normalize_1_res_reg[c_normalize_1_row] <= norm_res;
            if (c_normalize_1_row == SEQ_LEN-1) begin
                c_normalize_1_row <= '0;
                norm_inp_sel <= 2'b01;
            end
            else begin
                c_normalize_1_row <= c_normalize_1_row + 1;
            end
        end
        else if (c_state == Q_CALC) begin  
            q_col_res_reg[c_attn_row][c_q_k_v_col] <= fc_res;

            if (c_attn_row == SEQ_LEN-1) begin
                c_attn_row <= '0;

                if (c_q_k_v_col == D_MODEL-1) begin
                    c_q_k_v_col <= '0;
                end
                else begin
                    c_q_k_v_col <= c_q_k_v_col + 1;
                end
            end
            else begin
                c_attn_row <= c_attn_row + 1;
            end
        end
        else if (c_state == K_CALC) begin  
            k_col_res_reg[c_attn_row][c_q_k_v_col] <= fc_res;

            if (c_attn_row == SEQ_LEN-1) begin
                c_attn_row <= '0;

                if (c_q_k_v_col == D_MODEL-1) begin
                    c_q_k_v_col <= '0;
                end
                else begin
                    c_q_k_v_col <= c_q_k_v_col + 1;
                end
            end
            else begin
                c_attn_row <= c_attn_row + 1;
            end
        end
        else if (c_state == V_CALC) begin
            v_trans_col_res_reg[c_q_k_v_col][c_attn_row] <= fc_res;

            if (c_attn_row == SEQ_LEN-1) begin
                c_attn_row <= '0;

                if (c_q_k_v_col == D_MODEL-1) begin
                    c_q_k_v_col <= '0;
                end
                else begin
                    c_q_k_v_col <= c_q_k_v_col + 1;
                end
            end
            else begin
                c_attn_row <= c_attn_row + 1;
            end
        end
        else if (c_state == QK_PROD) begin
            if (c_qk_col <= c_attn_row) begin
                qk_res_reg[c_attn_row][c_qk_col] <= qk_res_scaled_fixed_point;
            end
            else begin
                qk_res_reg[c_attn_row][c_qk_col] <= {1'b1, {NUM_WIDTH{1'b0}}};
            end

            if (c_attn_row == SEQ_LEN-1) begin
                c_attn_row <= '0;

                if (c_qk_col == SEQ_LEN-1) begin
                    c_qk_col <= '0;
                end
                else begin
                    c_qk_col <= c_qk_col + 1;
                end
            end
            else begin
                c_attn_row <= c_attn_row + 1;
            end
        end
        else if (c_state == SOFTMAX) begin
            softmax_res_reg[c_softmax_row] <= softmax_res_bf16;
            if (c_softmax_row == SEQ_LEN-1) begin
                c_softmax_row <= '0;
            end
            else begin
                c_softmax_row <= c_softmax_row + 1;
            end
        end
        else if (c_state == V_PROD) begin
            v_prod_res_reg[c_attn_row][c_v_prod_col] <= fc_res;

            if (c_attn_row == SEQ_LEN-1) begin
                c_attn_row <= '0;

                if (c_v_prod_col == D_MODEL-1) begin
                    c_v_prod_col <= '0;
                end
                else begin
                    c_v_prod_col <= c_v_prod_col + 1;
                end
            end
            else begin
                c_attn_row <= c_attn_row + 1;
            end
        end
        else if (c_state == O_PROD) begin
            o_prod_col_res_reg[c_attn_row][c_o_prod_col] <= fc_res;

            if (c_attn_row == SEQ_LEN-1) begin
                c_attn_row <= '0;

                if (c_o_prod_col == D_MODEL-1) begin
                    c_o_prod_col <= '0;
                end
                else begin
                    c_o_prod_col <= c_o_prod_col + 1;
                end
            end
            else begin
                c_attn_row <= c_attn_row + 1;
            end
        end 
        else if (c_state == NORM_ADD_1) begin
            norm_add_1_res_reg[c_norm_add_1_row] <= norm_add_res;
            if (c_norm_add_1_row == SEQ_LEN-1) begin
                c_norm_add_1_row <= '0;
                norm_add_sel <= 1'b1;
            end
            else begin
                c_norm_add_1_row <= c_norm_add_1_row + 1;
            end
        end
        else if (c_state == NORMALIZE_2) begin
            normalize_2_res_reg[c_normalize_2_row] <= norm_res;
            if (c_normalize_2_row == SEQ_LEN-1) begin
                c_normalize_2_row <= '0;
                norm_inp_sel <= 2'b10;
            end
            else begin
                c_normalize_2_row <= c_normalize_2_row + 1;
            end
        end
        else if (c_state == FC_2) begin
            fc_2_res_reg[c_seq_len_fc_2][c_d_ff_fc_2] <= fc_res;
            if (c_d_ff_fc_2 == D_FF-1) begin
                c_d_ff_fc_2 <= '0;
                if (c_seq_len_fc_2 == SEQ_LEN-1) begin
                    fc_inp_sel <= 2'b10;
                    c_seq_len_fc_2 <= '0;
                end
                else begin
                    c_seq_len_fc_2 <= c_seq_len_fc_2 + 1;
                end
            end
            else begin
                c_d_ff_fc_2 <= c_d_ff_fc_2 + 1;
            end
        end
        else if (c_state == FC_3) begin
            fc_3_res_reg[c_seq_len_fc_3][c_d_model_fc_3] <= fc_res;
            if (c_d_model_fc_3 == D_MODEL-1) begin
                c_d_model_fc_3 <= '0;
                if (c_seq_len_fc_3 == SEQ_LEN-1) begin
                    fc_inp_sel <= 2'b11;
                    c_seq_len_fc_3 <= '0;
                end
                else begin
                    c_seq_len_fc_3 <= c_seq_len_fc_3 + 1;
                end
            end
            else begin
                c_d_model_fc_3 <= c_d_model_fc_3 + 1;
            end
        end
        else if (c_state == NORM_ADD_2) begin
            norm_add_2_res_reg[c_norm_add_2_row] <= norm_add_res;
            if (c_norm_add_2_row == SEQ_LEN-1) begin
                c_norm_add_2_row <= '0;
                norm_add_sel <= 1'b0;
            end
            else begin
                c_norm_add_2_row <= c_norm_add_2_row + 1;
            end
        end
        else if (c_state == FINAL_NORMALIZE) begin
            final_normalize_res_reg[c_final_normalize_row] <= norm_res;
            if (c_final_normalize_row == SEQ_LEN-1) begin
                c_final_normalize_row <= '0;
                norm_inp_sel <= 2'b00;
            end
            else begin
                c_final_normalize_row <= c_final_normalize_row + 1;
            end
        end 
        else if (c_state == FC_4) begin
            valid_out <= 1'b1;
            c_entry_fc_4 <= c_entry_fc_4 + 1;
        end
        else if (c_state == FC_4_FINAL) begin
            fc_inp_sel <= 2'b00;
            c_entry_fc_4 <= '0;
            done <= 1'b1;
        end
        else if (c_state == DONE) begin
            done <= 1'b0;
        end
    end
end

always_comb begin
    n_state = c_state;

    case (c_state)
        IDLE: begin
            if (ready == 1'b1) begin
                n_state = FC_1;
            end
        end

        FC_1: begin
            if ((c_seq_len_fc_1 == SEQ_LEN-1) && (c_d_model_fc_1 == D_MODEL-1)) begin
                n_state = POS_ENC;
            end
            else begin
                n_state = FC_1;
            end
        end

        POS_ENC: begin 
            if (c_seq_len_pos_enc == SEQ_LEN-1) begin
                n_state = NORMALIZE_1;
            end
            else begin
                n_state = POS_ENC;
            end
        end

        NORMALIZE_1: begin
            if (c_normalize_1_row == SEQ_LEN-1) begin
                n_state = Q_CALC;
            end
            else begin
                n_state = NORMALIZE_1;
            end
        end

        Q_CALC: begin
            if ((c_q_k_v_col == D_MODEL-1) && (c_attn_row == SEQ_LEN-1)) begin
                n_state = K_CALC;
            end
            else begin
                n_state = Q_CALC;
            end
        end

        K_CALC: begin
            if ((c_q_k_v_col == D_MODEL-1) && (c_attn_row == SEQ_LEN-1)) begin
                n_state = V_CALC;
            end
            else begin
                n_state = K_CALC;
            end
        end

        V_CALC: begin
            if ((c_q_k_v_col == D_MODEL-1) && (c_attn_row == SEQ_LEN-1)) begin
                n_state = QK_PROD;
            end
            else begin
                n_state = V_CALC;
            end
        end

        QK_PROD: begin
            if ((c_qk_col == SEQ_LEN-1) && (c_attn_row == SEQ_LEN-1)) begin
                n_state = SOFTMAX;
            end
            else begin
                n_state = QK_PROD;
            end
        end

        SOFTMAX: begin
           if (c_softmax_row == SEQ_LEN-1) begin
                n_state = V_PROD;
            end
            else begin
                n_state = SOFTMAX;
            end
        end

        V_PROD: begin
            if ((c_v_prod_col == D_MODEL-1) && (c_attn_row == SEQ_LEN-1)) begin
                n_state = O_PROD;
            end
            else begin
                n_state = V_PROD;
            end
        end

        O_PROD: begin
            if ((c_o_prod_col == D_MODEL-1) && (c_attn_row == SEQ_LEN-1)) begin
                n_state = NORM_ADD_1;
            end
            else begin
                n_state = O_PROD;
            end
        end

        NORM_ADD_1: begin
            if (c_norm_add_1_row == SEQ_LEN-1) begin
                n_state = NORMALIZE_2;
            end
            else begin
                n_state = NORM_ADD_1;
            end
        end

        NORMALIZE_2: begin
            if (c_normalize_2_row == SEQ_LEN-1) begin
                n_state = FC_2;
            end
            else begin
                n_state = NORMALIZE_2;
            end
        end

        FC_2: begin
            if ((c_seq_len_fc_2 == SEQ_LEN-1) && (c_d_ff_fc_2 == D_FF-1)) begin
                n_state = FC_3;
            end
            else begin
                n_state = FC_2;
            end
        end

        FC_3: begin
            if ((c_seq_len_fc_3 == SEQ_LEN-1) && (c_d_model_fc_3 == D_MODEL-1)) begin
                n_state = NORM_ADD_2;
            end
            else begin
                n_state = FC_3;
            end
        end

        NORM_ADD_2: begin
            if (c_norm_add_2_row == SEQ_LEN-1) begin
                n_state = FINAL_NORMALIZE;
            end
            else begin
                n_state = NORM_ADD_2;
            end
        end

        FINAL_NORMALIZE : begin
            if (c_final_normalize_row == SEQ_LEN-1) begin
                n_state = FC_4;
            end
            else begin
                n_state = FINAL_NORMALIZE;
            end
        end

        FC_4: begin
            if (c_entry_fc_4 == OUT_ENTRIES-1) begin
                n_state = FC_4_FINAL;
            end
            else begin
                n_state = FC_4;
            end
        end

        FC_4_FINAL: begin
            n_state = DONE;
        end

        DONE: begin
            n_state = IDLE;
        end

        default: begin
            n_state = IDLE;
        end
    endcase
end

always_comb begin

    fc_inp = '{default: 16'b0};
    neuron_weight = '{default: 16'b0};
    neuron_bias = '0;

    if (c_state == Q_CALC || c_state == K_CALC || c_state == V_CALC) begin
        for (int i = 0; i < D_MODEL; i++) begin
            fc_inp[i] = normalize_1_res_reg[c_attn_row][i];
            neuron_weight[i] = weights[i];
        end
        neuron_bias = bias;
    end
    else if (c_state == QK_PROD) begin
        for (int i = 0; i < D_MODEL; i++) begin
            fc_inp[i] = q_col_res_reg[c_attn_row][i];
            neuron_weight[i] = k_col_res_reg[c_qk_col][i];
        end
        neuron_bias = '0;
    end
    else if (c_state == V_PROD) begin
        for (int i = 0; i < SEQ_LEN; i++) begin 
            fc_inp[i] = softmax_res_reg[c_attn_row][i];
            neuron_weight[i] = v_trans_col_res_reg[c_v_prod_col][i];
        end
        neuron_bias = '0;
    end
    else if (c_state == O_PROD) begin
        for (int i = 0; i < D_MODEL; i++) begin
            fc_inp[i] = v_prod_res_reg[c_attn_row][i];
            neuron_weight[i] = weights[i];
        end
        neuron_bias = bias;
    end
    else begin
        neuron_weight = weights;
        neuron_bias = bias;

        if (fc_inp_sel == 2'b00) begin
            fc_inp = sensor_values;
        end
        else if (fc_inp_sel == 2'b01) begin
            for (int i = 0; i < D_MODEL; i++) begin
                fc_inp[i] = normalize_2_res_reg[c_seq_len_fc_2][i];
            end
        end
        else if (fc_inp_sel == 2'b10) begin
            for (int i = 0; i < D_FF; i++) begin
                fc_inp[i] = fc_2_res_reg[c_seq_len_fc_3][i];
            end    
        end
        else if (fc_inp_sel == 2'b11) begin
            for (int i = 0; i < FLAT_ENTRIES_NUM; i++) begin
                fc_inp[i] = flattened[i];
            end
        end 
    end

    norm_inp = '{default: 16'b0};

    if (norm_inp_sel == 2'b00) begin
        norm_inp = pos_enc_res_reg[c_normalize_1_row];
    end
    if (norm_inp_sel == 2'b01) begin
        norm_inp = norm_add_1_res_reg[c_normalize_2_row];
    end
    if (norm_inp_sel == 2'b10) begin
        norm_inp = norm_add_2_res_reg[c_final_normalize_row];
    end
    if (norm_inp_sel == 2'b11) begin
        norm_inp = '{default: 16'b0};
    end

    if (norm_add_sel == 1'b0) begin
        for (int i = 0; i < D_MODEL; i++) begin 
            norm_add_inp_1[i] = pos_enc_res_reg[c_norm_add_1_row][i];
            norm_add_inp_2[i] = o_prod_col_res_reg[c_norm_add_1_row][i];
        end
    end
    else begin
        for (int i = 0; i < D_MODEL; i++) begin
            norm_add_inp_1[i] = norm_add_1_res_reg[c_norm_add_2_row][i];
            norm_add_inp_2[i] = fc_3_res_reg[c_norm_add_2_row][i];
        end
    end
end

bf16_neuron #(
    .INP_NUM(N_S)
) fcl (
    .inp(fc_inp),
    .weight(neuron_weight),
    .bias(neuron_bias),
    .result(fc_res)
);

positional_encoder #(
    .D_MODEL(D_MODEL),
    .SEQ_LEN(SEQ_LEN)
) my_positional_encoder (
    .inp(fc_1_res_reg[c_seq_len_pos_enc]),
    .row(c_seq_len_pos_enc),
    .sum(pos_enc_res)
);

normalizer #(
    .INP_NUM(D_MODEL)
) my_normalizer (
    .inp(norm_inp),
    .alpha(weights[0]),
    .bias(weights[1]),
    .epsilon(weights[2]),
    .result(norm_res_fp32)
);

genvar normalize_var;

generate
    for (normalize_var = 0; normalize_var < D_MODEL; normalize_var++) begin
        fp32_to_bf16 my_fp32_to_bf16 (
            .inp(norm_res_fp32[normalize_var]),
            .out(norm_res[normalize_var])
        );
    end
endgenerate

bf16_to_fp32 my_qk_bf16_to_fp32 (
    .inp(fc_res),
    .out(qk_res_fp32)
); 

fp_mult qk_scaling (
    .a(qk_res_fp32),
    .b(INVERSE_SQRT_D_MODEL),
    .z(qk_res_scaled),
    .status()
);

fp32_to_bf16 my_qk_fp32_to_bf16 (
    .inp(qk_res_scaled),
    .out(qk_res_scaled_bf16)
);

bf16_to_fixed_point #(
    .INT_WIDTH(INT_WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH)
) qk_scaled_to_fixed_point (
    .inp(qk_res_scaled_bf16),
    .out(qk_res_scaled_fixed_point)
);

fixed_point_base_2_softmax #(
    .FRAC_WIDTH(FRAC_WIDTH),
    .INTEGER_WIDTH(INT_WIDTH),
    .INP_NUM(SEQ_LEN),
    .LUT_ENTRIES_NUM(LUT_ENTRIES_NUM)
) base_2_softmax (
    .inp(qk_res_reg[c_softmax_row]),
    .out(softmax_res)
);

genvar j;

generate
    for (j = 0; j < SEQ_LEN; j++) begin : TO_BF16_CONVERSION
        fixed_point_to_bf16 #(
            .INT_WIDTH(INT_WIDTH),
            .FRAC_WIDTH(FRAC_WIDTH)
        ) softmax_res_to_bf16 (
            .inp({1'b0, {(INT_WIDTH-1){1'b0}}, softmax_res[j]}),
            .out(softmax_res_bf16[j])
        );
    end
endgenerate

genvar kati_1;

generate 
    for (kati_1 = 0; kati_1 < D_MODEL; kati_1++) begin
        bf16_to_fp32 kati_1_1 (
            .inp(norm_add_inp_1[kati_1]),
            .out(norm_add_inp_1_fp32[kati_1])
        );

        bf16_to_fp32 kati_1_o_prod (
            .inp(norm_add_inp_2[kati_1]),
            .out(norm_add_inp_2_fp32[kati_1])
        );

        fp32_adder add_1_fp32_adder (
            .a(norm_add_inp_1_fp32[kati_1]),
            .b(norm_add_inp_2_fp32[kati_1]),
            .result(added_1[kati_1])
        );

        fp32_to_bf16 kati_1_fp32_to_bf16 (
            .inp(added_1[kati_1]),
            .out(norm_add_res[kati_1])
        );
    end
endgenerate

always_comb begin
    for (l = 0; l < SEQ_LEN; l++) begin
        for (m = 0; m < D_MODEL; m++) begin
            flattened[l*D_MODEL+m] = final_normalize_res_reg[l][m];
        end
    end
end

assign result_entry = fc_res;

endmodule