module uart_tx #(
    DATA_WIDTH = 8
) (
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    start,
    input  logic                    parity,
    input  logic [DATA_WIDTH - 1:0] tx_data,
    output logic                    tx,
    output logic                    ready,
    output logic                    done
);

    logic [DATA_WIDTH - 1:0] tx_data_buffer;
    logic [3:0] data_bit_cnt;
    logic parity_bit;

    enum logic [2:0] {
        IDLE   = 3'b000,
        START  = 3'b001,
        DATA   = 3'b010,
        PARITY = 3'b011,
        STOP   = 3'b100,
        DONE   = 3'b101
    } state;

    always_ff @(posedge clk) begin
        if (rst) begin
            tx <= 1;
            ready <= 1;
            done <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        tx <= 0;
                        ready <= 0;
                        tx_data_buffer <= tx_data;
                        data_bit_cnt <= DATA_WIDTH;
                        state <= START;
                    end
                end
                START: begin
                    // calculate parity bit before shifting
                    // even parity
                    parity_bit <= ^tx_data_buffer;
                    // shift first bit out
                    shift_tx_bit_out();
                    state <= DATA;
                end
                DATA: begin
                    if (data_bit_cnt == 0) begin
                        if (!parity) begin
                            tx <= 1;
                            state <= STOP;
                        end else begin
                            tx <= parity_bit;
                            state <= PARITY;
                        end
                    end else shift_tx_bit_out();
                end
                PARITY: begin
                    tx <= 1;
                    state <= STOP;
                end
                STOP: begin
                    done  <= 1;
                    state <= DONE;
                end
                DONE: begin
                    done  <= 0;
                    ready <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    task shift_tx_bit_out();
        tx <= tx_data_buffer[0];
        tx_data_buffer <= tx_data_buffer >> 1;
        data_bit_cnt <= data_bit_cnt - 1;
    endtask

endmodule
