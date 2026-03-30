`timescale 1ns/1ps

module cofre_tb;

    // -------------------------------------------------------------------------
    // Sinais
    // -------------------------------------------------------------------------
    logic       clk;
    logic       rst_n;
    logic [3:0] btn;   // 4 botoes, ativo baixo (1 = solto, 0 = pressionado)
    logic [3:0] leds;
    logic       unlock;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    cofre dut (
        .clk   (clk),
        .rst_n (rst_n),
        .btn   (btn),
        .leds  (leds),
        .unlock (unlock)
    );

    // -------------------------------------------------------------------------
    // Clock: 20ns -> 50 MHz
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: pressiona um botao especifico por hold_cycles ciclos e solta
    //   - btn_mask : botao a pressionar em logica POSITIVA
    //     ex: 4'b0001 = botao 0, 4'b0010 = botao 1
    //   - A task converte para ativo-baixo internamente:
    //     btn = ~btn_mask  -> bit pressionado fica em 0
    //   - Bits nao pressionados ficam em 1 (soltos)
    // -------------------------------------------------------------------------
    task press_button(input logic [3:0] btn_mask, input int hold_cycles);
        @(negedge clk);
        btn = ~btn_mask;               // Converte para ativo-baixo
        repeat (hold_cycles) @(posedge clk);
        @(negedge clk);
        btn = 4'b1111;                 // Solta tudo
        repeat (3) @(posedge clk);   // Aguarda borda ser detectada
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
    // Task: aplica reset p/ facilitar leitura
    // -------------------------------------------------------------------------
    task do_reset();
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Sequencia de testes
    // -------------------------------------------------------------------------
    initial begin
        // Dump de formas de onda para visualizacao no GTKWave
        $dumpfile("cofre.vcd");
        $dumpvars(0, cofre_tb);

        // Condicao inicial: todos os botoes soltos
        rst_n = 1'b1;
        btn   = 4'b1111;

        // ------------------------------------------------------------------
        // Teste 1: Reset
        //   Esperado: leds = S0 = 4'b0001 apos reset
        // ------------------------------------------------------------------
        $display("\n=== Teste 1: Reset inicial ===");
        do_reset();
        check_state(4'b0001, "Apos reset -> S0");

        // ------------------------------------------------------------------
        // Teste 2: Sequencia correta S0->S1->S2->S3->S4
        //   Combinacao: btn0, btn1, btn2, btn3 (nessa ordem)
        //   Cada botao so e valido no seu estado correspondente
        // ------------------------------------------------------------------
        $display("\n=== Teste 2: Sequencia correta S0->S1->S2->S3->S4 ===");

        press_button(4'b0001, 2);   // btn0 azul em S0 -> deve ir para S1
        check_state(4'b0010, "btn0 em S0 -> S1");

        press_button(4'b0010, 2);   // btn1 amarelo em S1 -> deve ir para S2
        check_state(4'b0100, "btn1 em S1 -> S2");

        press_button(4'b0010, 2);   // btn1 amarelo em S2 -> deve ir para S3
        check_state(4'b1000, "btn2 em S2 -> S3");

        press_button(4'b1000, 2);   // btn3 vermelho em S3 -> deve ir para S4 (aberto)
        check_state(4'b1111, "btn3 em S3 -> S4 (aberto)");

        // ------------------------------------------------------------------
        // Teste 3: Segurar o botao nao deve avancar mais de 1 estado
        //   Segura btn0 por 20 ciclos a partir de S0 -> so deve ir para S1
        // ------------------------------------------------------------------
        $display("\n=== Teste 3: Botao segurado (nao deve avancar mais de 1x) ===");
        do_reset();

        press_button(4'b0001, 20);  // Segura btn0 por 20 ciclos
        check_state(4'b0010, "btn0 segurado 20 ciclos -> apenas S1");

        press_button(4'b0010, 20);  // Segura btn1 por 20 ciclos em S1
        check_state(4'b0100, "btn1 segurado 20 ciclos -> apenas S2");

        // ------------------------------------------------------------------
        // Teste 4: Reset durante operacao
        //   Avanca ate S2 e aplica reset -> deve voltar para S0
        // ------------------------------------------------------------------
        $display("\n=== Teste 4: Reset durante operacao ===");
        do_reset();

        press_button(4'b0001, 2);   // S0->S1
        press_button(4'b0010, 2);   // S1->S2
        check_state(4'b0100, "Chegou em S2");

        do_reset();
        check_state(4'b0001, "Reset em S2 -> volta para S0");

        // ------------------------------------------------------------------
        // Teste 5: Botao errado reseta a sequencia para S0
        //   Em S1 o botao correto e btn1 (4'b0010)
        //   Pressionar btn0 novamente deve voltar para S0
        // ------------------------------------------------------------------
        $display("\n=== Teste 5: Botao errado reseta sequencia ===");
        do_reset();

        press_button(4'b0001, 2);   // S0->S1 (correto)
        check_state(4'b0010, "btn0 correto em S0 -> S1");

        press_button(4'b0001, 2);   // btn0 errado em S1 -> volta S0
        check_state(4'b0001, "btn0 errado em S1 -> volta S0");

        press_button(4'b0001, 2);   // Reinicia sequencia do zero
        check_state(4'b0010, "Reinicio: btn0 em S0 -> S1");

        press_button(4'b0100, 2);   // btn2 errado em S1 -> volta S0
        check_state(4'b0001, "btn2 errado em S1 -> volta S0");

        // ------------------------------------------------------------------
        // Teste 6: S4 ignora qualquer botao (trava permanece aberta)
        // ------------------------------------------------------------------
        $display("\n=== Teste 6: S4 ignora botoes ===");
        do_reset();

        press_button(4'b0001, 2);   // S0->S1
        press_button(4'b0010, 2);   // S1->S2
        press_button(4'b0010, 2);   // S2->S3
        press_button(4'b1000, 2);   // S3->S4
        check_state(4'b1111, "Chegou em S4");

        press_button(4'b0001, 2);   // Qualquer botao em S4 -> permanece S4
        check_state(4'b1111, "btn0 em S4 -> permanece S4");

        press_button(4'b1000, 2);
        check_state(4'b1111, "btn3 em S4 -> permanece S4");

        // ------------------------------------------------------------------
        // Teste 7: Multiplos botoes simultaneos
        //   Pressionar mais de um botao ao mesmo tempo deve resetar para S0
        //   independente do estado atual
        // ------------------------------------------------------------------
        $display("\n=== Teste 7: Multiplos botoes simultaneos ===");

        // --- 7a: Dois botoes em S0 ---
        $display("\nTeste 7a: Dois botões no S0:");
        do_reset();
        @(negedge clk);
        btn = 4'b1100;              // btn0 + btn1 simultaneos (ativo baixo)
        repeat (2) @(posedge clk);
        @(negedge clk);
        btn = 4'b1111;
        repeat (3) @(posedge clk);
        check_state(4'b0001, "btn0+btn1 simultaneos em S0 -> estado resultante");

        // --- 7b: Dois botoes em S1 (apos avanco correto) ---
        $display("\nTeste 7b: Dois botões no S1:");
        do_reset();
        press_button(4'b0001, 2);   // S0->S1 correto
        check_state(4'b0010, "Chegou em S1");
        @(negedge clk);
        btn = 4'b1001;              // btn1 + btn2 simultaneos
        repeat (2) @(posedge clk);
        @(negedge clk);
        btn = 4'b1111;
        repeat (3) @(posedge clk);
        check_state(4'b0001, "btn1+btn2 simultaneos em S1 -> estado resultante");

        // --- 7c: Todos os botoes ao mesmo tempo em S2 ---
        $display("\nTeste 7c: Todos os botoes ao mesmo tempo em S2:");
        do_reset();
        press_button(4'b0001, 2);   // S0->S1
        press_button(4'b0010, 2);   // S1->S2
        check_state(4'b0100, "Chegou em S2");
        @(negedge clk);
        btn = 4'b0000;              // Todos pressionados ao mesmo tempo
        repeat (2) @(posedge clk);
        @(negedge clk);
        btn = 4'b1111;
        repeat (3) @(posedge clk);
        check_state(4'b0001, "Todos botoes simultaneos em S2 -> estado resultante");

        $display("\n=== Simulacao concluida ===\n");
        $finish;
    end

endmodule