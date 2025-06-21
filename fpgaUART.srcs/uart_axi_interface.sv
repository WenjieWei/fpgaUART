`timescale 1ns / 1ps

module uart_axi_interface #( 
    
    parameter int TDATA_WIDTH = 16,                  // Data width from fft
    //parameter int NUM_BYTES   = (TDATA_WIDTH+7)/8,   // AXI bus width TODO: not sure what does +7 mean
    parameter int NUM_BYTES   = (TDATA_WIDTH + 7) / 8,     // AXI bus width, assuming TDATA_WIDTH is a multiple of 8
    parameter int CLK_FREQ    = 100_000_000,         // system clock frequency
    parameter int BAUD_RATE   =   9600               // UART baud rate
)(
    // clock and reset
    input logic                  clk,
    input logic                  arstn,

    // AXI4-Stream Slave Interface
    input logic [TDATA_WIDTH-1:0] s_axis_tdata,     // data from fft to process
    input logic s_axis_tvalid,    // valid flag from fft
    input logic uart_busy,          // UART is busy sending data. halts AXI feed
    
    output logic s_axis_tready,    // This module is ready. TODO: maybe feed start? 
    output logic [7:0] s_axis_data_output       // byte to be sent to uart_gen
);
    
    // Define state machine of the AXI module
    // Three states of a state machine IDLE SEND_BYTE DONE
    typedef enum logic [1:0] { IDLE, SEND_BYTE} state_t;
    state_t state, next_state;

    // Cache the wide bus and record the index of the bytes to be sent.
    logic [TDATA_WIDTH-1:0]         data_buf;
    logic [$clog2(NUM_BYTES)-1:0]   byte_idx;

    // Extracted sub-bytes, start pulses, and UART busy signals
    logic        start_byte;

    // AXI4-Stream Handshake: Only pull up ready when idle
    assign s_axis_tready = (state == IDLE);

    // Decompose bytes: LSB byte_idx=0, slice in order from high to low
    always_comb begin
        byte_to_send = data_buf[byte_idx * 8 +: 8];
        // equivalence: byte_to_send = byte_idx == 0 ? data_buf[7:0] : data_buf[15:8]
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
                // Send one byte at a time, waiting for the UART to be ready.
                // If the UART is busy, stay in SEND_BYTE state.
                if (!uart_busy) begin
                    // Not the last byte, continue
                    if (byte_idx != NUM_BYTES-1)
                        next_state = SEND_BYTE;
                    else
                        next_state = IDLE;
                end
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
            endcase
        end
    end

    // TODO: not sure what does this block do
    // start_byte is an internal signal and doesn't drive any other output
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
    /*
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
    );*/

endmodule

   