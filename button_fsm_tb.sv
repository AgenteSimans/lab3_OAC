// =============================================================================
// button_fsm_tb.sv
// Testbench para button_fsm.sv
//
// Simula:
//   [1] Reset inicial
//   [2] Varios pressionamentos do botao (verifica avanco de estados)
//   [3] Volta ao estado S0 apos 4 pressionamentos (ciclo completo)
//   [4] Segurar o botao pressionado (verifica que nao avanca mais de 1 vez)
// =============================================================================

`timescale 1ns/1ps

module button_fsm_tb;

    // -------------------------------------------------------------------------
    // Sinais de estimulo e observacao
    // -------------------------------------------------------------------------
    logic       clk;
    logic       rst_n;
    logic       btn;
    logic [3:0] leds;

    // -------------------------------------------------------------------------
    // Instancia do DUT (Device Under Test)
    // -------------------------------------------------------------------------
    button_fsm dut (
        .clk   (clk),
        .rst_n (rst_n),
        .btn   (btn),
        .leds  (leds)
    );

    // -------------------------------------------------------------------------
    // Geracao de clock: periodo de 20ns -> 50 MHz
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: pressiona o botao por alguns ciclos e solta
    //   - btn e ativo baixo na placa, mas aqui simulamos como ativo baixo:
    //     btn = 0 quando pressionado, btn = 1 quando solto
    //   - hold_cycles: quantos ciclos o botao fica pressionado
    // -------------------------------------------------------------------------
    task press_button(input int hold_cycles);
        @(negedge clk);
        btn = 1'b0;                    // Pressiona (ativo baixo)
        repeat (hold_cycles) @(posedge clk);
        @(negedge clk);
        btn = 1'b1;                    // Solta
        repeat (3) @(posedge clk);     // Aguarda estabilizar
    endtask

    // -------------------------------------------------------------------------
    // Task: verifica o estado dos LEDs e imprime resultado
    // -------------------------------------------------------------------------
    task check_state(input logic [3:0] expected, input string msg);
        @(negedge clk);
        if (leds === expected)
            $display("[PASS] %s | leds = 4'b%04b", msg, leds);
        else
            $display("[FAIL] %s | esperado = 4'b%04b, obtido = 4'b%04b",
                     msg, expected, leds);
    endtask

    // -------------------------------------------------------------------------
    // Sequencia de testes
    // -------------------------------------------------------------------------
    initial begin
        // Dump de formas de onda para visualizacao no GTKWave
        $dumpfile("button_fsm.vcd");
        $dumpvars(0, button_fsm_tb);

        // Condicao inicial
        rst_n = 1'b1;
        btn   = 1'b1;  // Botao solto (ativo baixo, entao 1 = solto)

        // ------------------------------------------------------------------
        // Teste 1: Reset
        // ------------------------------------------------------------------
        $display("\n=== Teste 1: Reset ===");
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check_state(4'b0001, "Apos reset -> S0");

        // ------------------------------------------------------------------
        // Teste 2: Avanca S0 -> S1 -> S2 -> S3 -> S0 (ciclo completo)
        // ------------------------------------------------------------------
        $display("\n=== Teste 2: Ciclo completo de estados ===");
        press_button(2);
        check_state(4'b0010, "1 pressionamento -> S1");

        press_button(2);
        check_state(4'b0100, "2 pressionamentos -> S2");

        press_button(2);
        check_state(4'b1000, "3 pressionamentos -> S3");

        press_button(2);
        check_state(4'b0001, "4 pressionamentos -> S0 (ciclo)");

        // ------------------------------------------------------------------
        // Teste 3: Segurar o botao nao deve avancar mais de 1 estado
        // ------------------------------------------------------------------
        $display("\n=== Teste 3: Botao segurado (nao deve avancar mais de 1x) ===");
        press_button(20);  // Segura por 20 ciclos
        check_state(4'b0010, "Botao segurado 20 ciclos -> apenas S1");

        // ------------------------------------------------------------------
        // Teste 4: Reset durante operacao
        // ------------------------------------------------------------------
        $display("\n=== Teste 4: Reset durante operacao ===");
        press_button(2);  // Vai para S2
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check_state(4'b0001, "Reset em S2 -> volta para S0");

        $display("\n=== Simulacao concluida ===\n");
        $finish;
    end

endmodule
