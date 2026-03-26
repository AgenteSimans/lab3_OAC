module button_fsm (
    input  logic       clk,     // Clock de 50 MHz
    input  logic       rst_n,   // Reset assincrono, ativo baixo (KEY[0])
    input  logic [3:0] btn,     // 
    output logic       unlocked
);

// ──────────────────────────────────────────
// Definicao dos estados
// ──────────────────────────────────────────
// mudar as variaveis logicas
typedef enum logic [2:0] {
        IDLE        = 3'b000, // Estado inicial / aguardando 1º botão (Azul)
        AZUL_OK     = 3'b001, // Azul inserido, aguardando 2º botão (Amarelo)
        AMARELO1_OK = 3'b010, // Amarelo inserido, aguardando 3º botão (Amarelo)
        AMARELO2_OK = 3'b011, // Amarelo inserido, aguardando 4º botão (Vermelho)
        UNLOCKED    = 3'b100  // Sequência correta inserida (Cofre aberto)
} state_t;
state_t state, next_state;

// ──────────────────────────────────────────
// Deteccao de borda de subida (0 → 1)
// ──────────────────────────────────────────
logic [3:0] btn_prev;
logic       btn_event;
logic       is_onehot;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_prev <= 4'b0000;
    else        btn_prev <= btn;
end

assign btn_event = (btn != 4'b0000) && (btn_prev == 4'b0000);
assign is_onehot = (btn == 4'b0001) || (btn == 4'b0010) || (btn == 4'b0100) || (btn == 4'b1000);

// ──────────────────────────────────────────
// Validacaoo one-hot
// ──────────────────────────────────────────
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
end

// ──────────────────────────────────────────
// Mudanca de estados
// ──────────────────────────────────────────
always_comb begin
        next_state = state; // Mantem o estado atual por padrao
        unlocked   = 1'b0;  // Saida padrao

        if (state == UNLOCKED) begin
            unlocked = 1'b1; // Mantem a saída em 1 quando destravado
        end

        if (btn_event) begin
            if (!is_onehot) begin
                next_state = IDLE; // Retorna ao início se multiplos botoes forem pressionados
            end else begin
                case (state)
                    IDLE: begin
                        if (btn == 4'b0001) next_state = AZUL_OK;
                        else next_state = IDLE; // Erro na sequência
                    end
                    AZUL_OK: begin
                        if (btn == 4'b0010) next_state = AMARELO1_OK;
                        else next_state = IDLE; // Erro na sequência
                    end
                    AMARELO1_OK: begin
                        if (btn == 4'b0010) next_state = AMARELO2_OK;
                        else next_state = IDLE; // Erro na sequência
                    end
                    AMARELO2_OK: begin
                        if (btn == 4'b1000) next_state = UNLOCKED;
                        else next_state = IDLE; // Erro na sequência
                    end
                    UNLOCKED: begin
                        next_state = UNLOCKED; // Permanece destravado ate o reset
                    end
                    default: next_state = IDLE;
                endcase
            end
        end
    end

endmodule
