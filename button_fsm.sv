// =============================================================================
// button_fsm.sv
// FSM didatica: avanca de estado a cada pressionamento de botao
//
// Objetivo: ponto de partida para discutir em aula
//   [1] Sintaxe SystemVerilog para FSMs (typedef enum, always_ff, always_comb)
//   [2] Deteccao de borda de subida do botao (edge detection)
//   [3] Codificacao de estados one-hot e por que e boa para FPGAs
//   [4] Separacao datapath (saida) x controle (FSM)
//
// Hardware alvo: DE2-115 (Cyclone IV E, clock de 50 MHz)
//   CLOCK_50       -> clk
//   KEY[0]         -> rst_n  (reset, ativo em nivel baixo)
//   KEY[1]         -> btn    (avanca estado, ativo em nivel baixo)
//   LEDR[3:0]      -> leds   (indica estado atual)
// =============================================================================

module button_fsm (
    input  logic       clk,    // Clock de 50 MHz
    input  logic       rst_n,  // Reset assincrono, ativo baixo (KEY[0])
    input  logic       btn,    // Botao de avanco, ativo baixo  (KEY[1])
    output logic [3:0] leds    // LEDs indicadores de estado
);

// -----------------------------------------------------------------------------
// [1] DEFINICAO DOS ESTADOS -- typedef enum
//
//   Usamos "typedef enum" para dar nomes aos estados em vez de usar numeros
//   "soltos" no codigo. Isso melhora muito a legibilidade.
//
//   Codificacao ONE-HOT: cada estado tem exatamente 1 bit em '1'.
//   Por que e boa para FPGA?
//     -> FPGAs tem flip-flops sobrando, mas LUTs sao escassas.
//     -> One-hot usa mais FFs, mas simplifica a logica combinacional
//        (cada transicao depende de apenas 1 bit de estado).
//     -> Saidas de Moore viram acesso direto ao bit do estado, sem decoder.
//
//   Codificacao binaria (alternativa, mais compacta):
//     S0 = 2'b00, S1 = 2'b01, S2 = 2'b10, S3 = 2'b11
//     -> Melhor para ASICs onde area e critica.
// -----------------------------------------------------------------------------
typedef enum logic [4:0] { //cada passo 
    S0 = 5'b00001, //passo 1 ,standby
    S1 = 5'b00010, //passo 2 ,espera o 2 botao certo
    S2 = 5'b00100, //passo 3 ,agora o 3
    S3 = 5'b01000, //passo 4 ,agora o ultimo
    S4 = 5'b10000  //passo 5 ,abriu
} state_t;

state_t state, next_state;

// -----------------------------------------------------------------------------
// [2] DETECCAO DE BORDA DE SUBIDA (edge detection)
//
//   Problema: se checarmos btn direto na FSM, ela avanca em TODOS os ciclos
//   em que o botao estiver pressionado (dezenas de milhares de ciclos a 50MHz).
//   Queremos avancar apenas 1 vez por pressionamento.
//
//   Solucao: detectar a BORDA DE SUBIDA -- o momento exato em que o botao
//   passa de solto (0) para pressionado (1), gerando um pulso de 1 ciclo.
//
//   Passo 1 -- Inverter polaridade (botao e ativo baixo na placa):
//     btn_active = ~btn    ->  0 quando solto, 1 quando pressionado
//
//   Passo 2 -- Guardar o valor do botao no ciclo anterior:
//     btn_prev <- btn_active   (registrado no FF)
//
//   Passo 3 -- Borda de subida = estava em 0, agora esta em 1:
//     btn_rise = btn_active AND (NOT btn_prev)
//
//   Diagrama de temporizacao:
//
//     clk:        _|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_
//     btn_active: _________|-----------------|_______
//     btn_prev:   _______________|-----------------|_
//     btn_rise:   _____________|-|___________________ <- pulso de 1 ciclo
// -----------------------------------------------------------------------------
logic btn_active;  // Botao em logica positiva (1 = pressionado)
logic btn_prev;    // Valor do botao no ciclo anterior
logic btn_rise;    // Pulso de 1 ciclo na borda de subida

assign btn_active = ~btn;
assign btn_rise   = btn_active & ~btn_prev;  // Borda de subida

// Registra o estado anterior do botao (FF simples)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_prev <= 1'b0;
    else        btn_prev <= btn_active;
end

// -----------------------------------------------------------------------------
// [3] PROCESSO SEQUENCIAL -- Registro de estado
//
//   "always_ff" indica ao sintetizador que este bloco DEVE ser implementado
//   como flip-flops. E mais seguro que "always @(posedge clk)" porque a
//   ferramenta emite erro se a logica nao for puramente sequencial.
//
//   Reset ASSINCRONO (negedge rst_n na sensibilidade):
//     -> Estado inicial e carregado IMEDIATAMENTE ao apertar reset,
//        independentemente do clock. Util para inicializacao da placa.
//
//   Atribuicoes NAO-BLOQUEANTES (<=):
//     -> Obrigatorias em always_ff. Todos os lados direitos sao avaliados
//        primeiro; os FFs atualizam ao mesmo tempo no final do ciclo.
//     -> Contraponto: always_comb usa atribuicoes BLOQUEANTES (=),
//        onde cada linha bloqueia a proxima ate ser concluida.
// -----------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S0;
    else        state <= next_state;
end

// -----------------------------------------------------------------------------
// [4] PROCESSO COMBINACIONAL -- Logica de proximo estado
//
//   "always_comb" e equivalente a always @(*) mas mais seguro:
//     -> O simulador adiciona automaticamente todos os sinais lidos na
//        lista de sensibilidade, evitando bugs silenciosos.
//     -> O sintetizador emite aviso se inferir latches por engano.
//
//   Atribuicoes BLOQUEANTES (=):
//     -> Cada linha e avaliada em ordem; o valor atribuido e imediatamente
//        visivel para as linhas seguintes dentro do mesmo bloco.
//     -> Contraponto: always_ff usa atribuicoes NAO-BLOQUEANTES (<=).
//
//   "next_state = state" como DEFAULT:
//     -> Garante que next_state sempre tem um valor atribuido.
//     -> Evita a inferencia de latches (latch ocorre quando uma saida
//        combinacional nao e atribuida em algum caminho do codigo).
//
//   "unique case":
//     -> Avisa se dois cases forem verdadeiros ao mesmo tempo (nao deve
//        acontecer com one-hot bem formado).
//     -> Avisa se um case nao for coberto (junto com default).
// -----------------------------------------------------------------------------
always_comb begin
    next_state = state;  // Default: mantem estado se nao houver borda

    unique case (state)
        S0: if (btn_rise) next_state = S1;
        S1: if (btn_rise) next_state = S2;
        S2: if (btn_rise) next_state = S3;
        S3: if (btn_rise) next_state = S0;  // Volta ao inicio -> ciclo
        default:          next_state = S0;
    endcase
end

// -----------------------------------------------------------------------------
// [5] SAIDA -- Logica de Moore
//
//   Maquina de Moore: saida depende APENAS do estado atual (nao das entradas).
//   Isso torna a saida estavel entre transicoes.
//
//   Com one-hot, cada LED corresponde diretamente a 1 bit do estado.
//   Nao precisamos de nenhuma logica de decodificacao -- a saida
//   e simplesmente o proprio vetor de estado!
//
//     state = 4'b0001 (S0) -> leds = 4'b0001 -> apenas LEDR[0] aceso
//     state = 4'b0010 (S1) -> leds = 4'b0010 -> apenas LEDR[1] aceso
//     ...
// -----------------------------------------------------------------------------
assign leds = state;

endmodule
