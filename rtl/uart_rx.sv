module uart_rx #(
    DATA_WIDTH = 8,
    SAMPLING_RATE = 16,
    NUM_POLLS = 5
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      rx,
    input  logic                      parity,
    output logic [DATA_WIDTH - 1 : 0] data,
    output logic                      ready,
    output logic                      valid,
    output logic                      done
);

    /* sampling e.g. sample_rate = 8, polls = 4
     clocks       * * * * * * * *
     samples          | | | |
    */

   localparam                          MID_CYCLE          = (SAMPLING_RATE / 2) - 1;
   localparam                          FIRST_SAMPLE_CYCLE = MID_CYCLE - (int'(NUM_POLLS / 2)) + (NUM_POLLS % 2 == 0); // to achieve symmetrical sampling
   localparam                          LAST_SAMPLE_CYCLE  = MID_CYCLE + (int'(NUM_POLLS / 2));
   localparam                          MAJORITY           = (int'(NUM_POLLS / 2)) + 1;

   logic [$clog2(SAMPLING_RATE) - 1:0] clk_cnt;
   logic [$clog2(SAMPLING_RATE) - 1:0] next_clk_cnt;
   logic [ 3:0]                        bit_cnt;
   logic [ 3:0]                        next_bit_cnt;
   logic [ DATA_WIDTH - 1:0]           data_buffer;
   logic [ DATA_WIDTH - 1:0]           next_data_buffer;

   logic [ $clog2(NUM_POLLS):0]        poll_adder;
   logic [ $clog2(NUM_POLLS):0]        next_poll_adder;
   logic                               parity_bit;
   logic                               next_parity_bit;

   logic [ 1:0]                        r_rx;
   logic                               sync_rx;
   logic                               polled_rx;
   logic                               store_polled_rx;
   logic                               in_sampling_cycles;
   logic                               tx_clk_cycle_end;


   typedef enum logic [2:0] {
        IDLE   = 3'b000,
        START  = 3'b001,
        DATA   = 3'b010,
        PARITY = 3'b011,
        STOP   = 3'b100,
        DONE   = 3'b101
   } state_t;
   state_t state, next_state;

   // 2 FF Synchronizer
   always_ff @(posedge clk) begin
      r_rx[1] <= rx;
      r_rx[0] <= r_rx[1];
   end

   assign sync_rx = r_rx[0];
   // The rx bit is determined by the majority of the samples
   assign polled_rx = (poll_adder >= MAJORITY);
   assign data = data_buffer;
   // data are only valid if there is even parity
   // if parity is disabled, assume valid
   assign valid = (~^{data_buffer, parity_bit}) || !parity;
   assign in_sampling_cycles = clk_cnt >= FIRST_SAMPLE_CYCLE && clk_cnt <= LAST_SAMPLE_CYCLE;
   assign tx_clk_cycle_end = (clk_cnt == SAMPLING_RATE - 1);
   assign store_polled_rx = (clk_cnt == (LAST_SAMPLE_CYCLE + 1));

   // State FF for state
   always_ff @(posedge clk) begin
       if (rst) state <= IDLE;
       else state <= next_state;
   end

   always_ff @(posedge clk) begin
      bit_cnt     <= next_bit_cnt;
      clk_cnt     <= next_clk_cnt;
      poll_adder  <= next_poll_adder;
      data_buffer <= next_data_buffer;
      parity_bit  <= next_parity_bit;
   end

   always_comb begin
      // loopback
      next_bit_cnt     = bit_cnt;
      next_clk_cnt     = clk_cnt;
      next_poll_adder  = poll_adder;
      next_data_buffer = data_buffer;
      next_parity_bit  = parity_bit;

       case (state)
           IDLE: begin
              next_bit_cnt     = DATA_WIDTH - 1;
              next_clk_cnt     = 0;
              next_poll_adder  = 0;
              next_data_buffer = data_buffer;
              ready            = 1;
              done             = 0;

               if (!sync_rx) next_state = START;
               else next_state = IDLE;
           end

           START: begin
              next_clk_cnt = clk_cnt + 1;
              ready        = 0;
              done         = 0;

               // accumulate adder, if the current cycle is between +/- SAMPLE_RATE/2 from the middle
               unique if (in_sampling_cycles) begin
                   next_poll_adder = poll_adder + sync_rx;
                   next_state      = START;
               end else if (tx_clk_cycle_end) begin
                   // reset clock counter and poll adder
                   next_clk_cnt    = 0;
                   next_poll_adder = 0;
                   if (!polled_rx) next_state = DATA;
                   else next_state = IDLE;
               end else next_state = START;
           end

           DATA: begin
              next_clk_cnt = clk_cnt + 1;
              ready        = 0;
              done         = 0;

               unique if (in_sampling_cycles) begin
                  next_poll_adder = poll_adder + sync_rx;
                  next_state      = DATA;
               end else if (store_polled_rx) begin
                  next_data_buffer = {polled_rx, data_buffer[DATA_WIDTH-1:1]};
                  next_state       = DATA;
               end else if (tx_clk_cycle_end) begin
                  next_bit_cnt    = bit_cnt - 1;
                  next_clk_cnt    = 0;
                  next_poll_adder = 0;
                  if (bit_cnt == 0) begin
                      if (parity) next_state = PARITY;
                      else next_state = STOP;
                  end
                  // if transfer isn't finished, remain in state
                  else next_state = DATA;
               end else next_state = DATA;
           end

           PARITY: begin
              next_clk_cnt = clk_cnt + 1;
              ready        = 0;
              done         = 0;

               unique if (in_sampling_cycles) begin
                  next_poll_adder = poll_adder + sync_rx;
                  next_state      = PARITY;
               end else if (store_polled_rx) begin
                  next_parity_bit = polled_rx;
                  next_state      = PARITY;
               end else if (tx_clk_cycle_end) begin
                   next_clk_cnt = 0;
                   next_state   = STOP;
               end else next_state = PARITY;
           end

           STOP: begin
              next_clk_cnt = clk_cnt + 1;
              ready        = 0;
              done         = 0;

               if (tx_clk_cycle_end) next_state = DONE;
               else next_state = STOP;
           end

            DONE: begin
               ready      = 0;
               done       = 1;
               next_state = IDLE;
            end

            default: begin
               ready      = 0;
               done       = 0;
               next_state = IDLE;
            end

       endcase
   end

endmodule
