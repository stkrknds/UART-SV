
`timescale 1s / 1ps

module uart_tb;

    int TESTS = 100;
    parameter DATA_WIDTH = 8;

    parameter BAUD_RATE = 921600;

    parameter POLLING_RATE = 4;
    parameter SAMPLE_RATE = 16;

    localparam TX_FREQ = BAUD_RATE;
    localparam RX_FREQ = BAUD_RATE * SAMPLE_RATE;

    logic                    tx_clk;
    logic                    rx_clk;
    logic                    rst;
    logic                    start;
    logic                    parity;
    logic                    tx_rx;
    logic                    tx_ready;
    logic                    rx_ready;
    logic [DATA_WIDTH - 1:0] tx_data;
    logic [DATA_WIDTH - 1:0] rx_data;

    logic                    tx_done;
    logic                    rx_done;

    logic                    rx_valid;

    uart_tx #(
        .DATA_WIDTH(DATA_WIDTH)
    ) tx_dut (
        // Inputs
        .clk(tx_clk),
        .rst(rst),
        .start(start),
        .parity(parity),
        .tx_data(tx_data),
        // Outputs
        .tx(tx_rx),
        .ready(tx_ready),
        .done(tx_done)
    );

    uart_rx #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLING_RATE(SAMPLE_RATE),
        .NUM_POLLS(POLLING_RATE)
    ) rx_dut (
        // Inputs
        .clk(rx_clk),
        .rst(rst),
        .rx(tx_rx),
        .parity(parity),
        // Outputs
        .data(rx_data),
        .ready(rx_ready),
        .done(rx_done),
        .valid(rx_valid)
    );

    initial gen_clock(TX_FREQ, tx_clk);
    initial gen_clock(RX_FREQ, rx_clk);

    initial begin
        rst = 1;
        @(posedge tx_clk) rst = 0;
        for (int i = 0; i < TESTS; i++) begin
            tx_data = $urandom_range(0, 2 ^ (DATA_WIDTH) - 1);
            parity  = $urandom_range(0, 1);
            $display("Test no. %d, parity = %b \n", i, parity);
            wait (tx_ready);
            wait (rx_ready);
            check_idle_tx_rx();
            start = 1;
            @(negedge tx_rx) start = 0;

            wait (tx_done);
            wait (rx_done);

            check_idle_tx_rx();

            assert (tx_data == rx_data)
            else $fatal(0, "Data not equal. \n");

            assert (!parity || (parity && rx_valid))
            else $fatal(0, "Data not valid. \n");

        end

        $display("Tests completed successfully. \n");
        $stop;
    end

    function void check_idle_tx_rx();
        assert (tx_rx)
        else $fatal(0, "Idle tx not 1. \n");
    endfunction

    task automatic gen_clock(input real freq, ref logic clock);
        real clk_half_period;

        clk_half_period = 2 / freq;
        clock = 0;

        forever #(clk_half_period) clock = ~clock;
    endtask

endmodule
