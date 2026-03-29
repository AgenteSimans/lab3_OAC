

module button_fsm (
    input  logic       clk,    // Clock de 50 MHz
    input  logic       rst_n,  // Reset assincrono, ativo baixo (KEY[0])
    input  logic [3:0] btn,    // Botao de avanco, ativo baixo  (KEY[1])
    output logic [3:0] leds    // LEDs indicadores de estado
);

typedef enum logic [3:0] {
    S0 = 4'b0001,   // Estado inicial  -- LEDR[0] aceso
    S1 = 4'b0010,   // Estado 1        -- LEDR[1] aceso
    S2 = 4'b0100,   // Estado 2        -- LEDR[2] aceso
    S3 = 4'b1000,   // Estado 3        -- LEDR[3] aceso
    S1 = 4'b1111
} state_t;

state_t state, next_state;


logic [3:0] btn_active;  // Botao em logica positiva (1 = pressionado)
logic [3:0] btn_prev;    // Valor do botao no ciclo anterior
logic [3:0] btn_rise;    // Pulso de 1 ciclo na borda de subida

assign btn_active = ~btn;
assign btn_rise   = btn_active & ~btn_prev;  // Borda de subida

// Registra o estado anterior do botao (FF simples)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_prev <= 4'b0000;
    else        btn_prev <= btn_active;
end


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S0;
    else        state <= next_state;
end


always_comb begin
    next_state = state;  // Default: mantem estado se nao houver borda

    unique case (state)
        S0: if      (btn_rise == 4b0001)  next_state = S1;

        S1: if      (btn_rise == 4b0010)  next_state = S2;
            else if (btn_rise == 4b0000)  next_state = S1;
            else                          next_state = S0;
        
        S2: if      (btn_rise == 4b0100)  next_state = S3;
            else if (btn_rise == 4b0000)  next_state = S2;
            else                          next_state = S0;
        
        S3: if      (btn_rise == 4b1000)  next_state = S4;  // Volta ao inicio -> ciclo
            else if (btn_rise == 4b0000)  next_state = S3;
            else                          next_state = S0;
        
        S4: next_state = S4;
        default:          next_state = S0;
    endcase
end

assign leds = state;

endmodule
