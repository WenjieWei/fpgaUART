/*`timescale 1ns / 1ps

/**
 *  UART AXI Interface
 *  This module serves as an interface between the UART generator and AXI bus.
 *  It will handle the AXI transactions and connect to the UART generator.
 */
 
 
 /*module uart_axi_interface#(
        parameter TDATA_WIDTH = 32,                 // Width of the data bus
        parameter NUM_BYTES = (TDATA_WIDTH+7)/8     // Number of bytes in the AXI transaction
    )(
    
       AXI4_stream Slave
        input  logic [TDATA_WIDTH-1:0] s_axis_tdata,   //Data bus: The upstream module places the â€œwide busâ€? data to be sent here.
        input  logic                   s_axis_tvalid,  //Data valid: When the upstream module places valid data on tdata, raise tvalid.
        output logic                   s_axis_tready,  //Ready notification

    // Transcation TX
        output logic                    uart_tx        
    );

    // Internal states: IDLE to SEND_BYTE to DONE
        typedef enum logic [1:0] { IDLE, SEND_BYTE, DONE } state_t; 
        state_t  state, next_state;                   
    
    // Save_Width_lengtn_data
        logic [TDATA_WIDTH-1:0] data_buf;              //Used to cache the entire AXI4-Stream wide bus data
        logic [$clog2(NUM_BYTES)-1:0] byte_idx;        //Used to record which byte is currently being sent.

    // connect to uart_gen
        logic [7:0]  byte_to_send;                     //8-bit sub-byte to be sent to uart_gen
        logic        start_byte;                       //Single-cycle pulse to drive uart_gen to start transmission
        wire         uart_busy;                        //get the uart_busy from uart_gen
    
    // AXI4-Stream ready
        assign s_axis_tready = (state == IDLE);   //only recieve new data when IDLE

    // Byte spliting
        always_comb begin
    //  byte_idx ï¼šthe bit of LSBbyte_idx=0
        byte_to_send = data_buf[ byte_idx*8 +: 8 ]; //Extract the byte_idxth byte from data_buf
  end

    // Status register
  always_ff @(posedge clk or negedge arstn) begin   
    if (!arstn)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Lower state logic 
  always_comb begin
    next_state = state;
    case(state)
      // Once TDATA is received, it is cached and starts sending byte 0 
      IDLE: if (s_axis_tvalid) next_state = SEND_BYTE;

      // After a frame of TX is completed (uart_busy changes from 1â†?0): 
      SEND_BYTE: if (!uart_busy) begin
        if (byte_idx == NUM_BYTES-1) next_state = DONE;
        else                         next_state = SEND_BYTE;
      end

      // After all bytes are sent, return to IDLE 
      DONE: next_state = IDLE;
    endcase
  end

  // Data Cache & Byte Index 
  always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
      data_buf <= '0;
      byte_idx <= '0;
    end else begin
      case(state)
        IDLE: if (s_axis_tvalid) begin
          data_buf <= s_axis_tdata;
          byte_idx <= '0;
        end

        SEND_BYTE: if (!uart_busy) begin
          byte_idx <= byte_idx + 1;
        end
      */






  `timescale 1ns / 1ps
module uart_axi_interface #( 
    
    parameter int TDATA_WIDTH = 32,                  // How many bytes should it be split into
    parameter int NUM_BYTES   = (TDATA_WIDTH+7)/8,   // AXI bus width
    parameter int CLK_FREQ    = 100_000_000,         // system clock frequency
    parameter int BAUD_RATE   =   115200             // UART baud rate
)(
    // clock and reset
    input  logic                  clk,
    input  logic                  arstn,

    // ?? AXI4-Stream Slave Interface?? 
    input  logic [TDATA_WIDTH-1:0] s_axis_tdata,     // Upstream parallel data
    input  logic                   s_axis_tvalid,    // Upstream effective
    output logic                   s_axis_tready,    // This module is ready.

    // ?? Serial port TX output ? 
    output logic                   uart_tx
);

    // Three states of a state machine IDLE ? SEND_BYTE  DONE
    typedef enum logic [1:0] { IDLE, SEND_BYTE, DONE } state_t;
    state_t state, next_state;

    // Cache the wide bus and record the index of the bytes to be sent.
    logic [TDATA_WIDTH-1:0]      data_buf;
    logic [$clog2(NUM_BYTES)-1:0] byte_idx;

    // Extracted sub-bytes, start pulses, and UART busy signals
    logic  [7:0] byte_to_send;
    logic        start_byte;
    wire         uart_busy;

    // AXI4-Stream Handshake: Only pull up ready when idle
    assign s_axis_tready = (state == IDLE);

    // Decompose bytes: LSB byte_idx=0, slice in order from high to low
    always_comb begin
        byte_to_send = data_buf[ byte_idx*8 +: 8 ];
    end

    // Status register (including asynchronous reset)
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn)    state <= IDLE;
        else           state <= next_state;
    end

    // Lower-order logic (combinatorial logic)
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                // Both tvalid and tready must be satisfied at the same time to obtain AXI data.
                if (s_axis_tvalid && s_axis_tready)
                    next_state = SEND_BYTE;

            SEND_BYTE:
                // After sending one byte (uart_busy from 1â†?0)ï¼?
                if (!uart_busy) begin
                    // Not the last byte, continue
                    if (byte_idx != NUM_BYTES-1)
                        next_state = SEND_BYTE;
                    else
                        next_state = DONE;
                end

            DONE:
                // All bytes sent, return to IDLE
                next_state = IDLE;
        endcase
    end

    // Cache data & update byte_idx (sequential logic)
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            data_buf <= '0;
            byte_idx <= '0;
        end else begin
            case (state)
                IDLE: begin
                    // Cache only when handshake is successful
                    if (s_axis_tvalid && s_axis_tready) begin
                        data_buf <= s_axis_tdata;
                        byte_idx <= '0;
                    end
                end

                SEND_BYTE: begin
                    // Once a frame byte has been sent, the index is incremented by 1.
                    if (!uart_busy)
                        byte_idx <= byte_idx + 1;
                end

                DONE: /* nothing */;
            endcase
        end
    end

    // Generate a single-cycle start_byte pulse to drive uart_gen.
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn)
            start_byte <= 1'b0;
        else begin
            start_byte <= 1'b0;
            // From IDLE to SEND_BYTE, or at the end of each SEND_BYTE cycle
            if (state==IDLE     && next_state==SEND_BYTE) start_byte <= 1'b1;
            if (state==SEND_BYTE && next_state==SEND_BYTE && !uart_busy)
                start_byte <= 1'b1;
        end
    end

    // Instantiate the UART transmitter, passing in the clock and baud rate parameters.
    uart_gen #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_i (
        .clk        (clk),
        .arstn      (arstn),
        .data_in    (byte_to_send),
        .start      (start_byte),
        .tx_output  (uart_tx),
        .tx_busy    (uart_busy),
        .data_out   ()        // 
    );

endmodule

   