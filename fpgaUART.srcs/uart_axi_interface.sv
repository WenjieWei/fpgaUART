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
    input logic uart_tx_complete, // UART transmission complete signal
    
    output logic s_axis_tready,    // This module is ready. 
    output logic s_axis_uart_ready, // ready to send next byte to uart_gen TODO: maybe feed start? 
    output logic [7:0] s_axis_data_output       // byte to be sent to uart_gen
);
    
    // Define state machine of the AXI module
    // Three states of a state machine IDLE SEND_BYTE DONE
    typedef enum logic [2:0] { IDLE, SEND_BYTE, DONE} state_t;
    state_t state, next_state;

    // Cache the wide bus and record the index of the bytes to be sent.
    logic [TDATA_WIDTH-1:0]         data_buf;
    logic [$clog2(NUM_BYTES):0]   byte_idx;

    // Extracted sub-bytes, start pulses, and UART busy signals
    logic        start_byte;

    // AXI4-Stream Handshake: Only pull up ready when idle
    assign s_axis_tready = (state == IDLE);

    // Decompose bytes: LSB byte_idx=0, slice in order from high to low
    always_comb begin
        s_axis_data_output = data_buf[byte_idx * 8 +: 8];
        // equivalence: s_axis_data_output = byte_idx == 0 ? data_buf[7:0] : data_buf[15:8]
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
                else
                    next_state = IDLE;

            SEND_BYTE:
                // Send one byte at a time, waiting for the UART to be ready.
                // If the UART is busy, stay in SEND_BYTE state.
                // If UART is idle again, that means the byte has been sent, transition to DONE
                /*
                if (!uart_busy && !uart_tx_complete) begin
                    // Not the last byte, but tx_complete signal not received, continue
                    if (byte_idx < NUM_BYTES - 1 && !uart_tx_complete)
                        next_state = SEND_BYTE;*/
                if (!uart_busy) begin
                    if (byte_idx < NUM_BYTES - 1) begin
                        if (uart_tx_complete) byte_idx = byte_idx + 1; // Increment byte index
                        next_state = SEND_BYTE; // More bytes to send
                        s_axis_uart_ready = 1'b1; // Ready to send next byte
                    end else begin
                        next_state = DONE; // All bytes sent, go to DONE state
                        s_axis_uart_ready = 1'b0; // Not ready to send more bytes
                    end
                end

            DONE:
                if (byte_idx >= NUM_BYTES - 1) begin
                    next_state = IDLE; // All bytes sent, go back to IDLE
                    byte_idx <= 0; // Reset byte index for next packet
                end

            default:
                next_state = IDLE; // Default case to avoid latches
        endcase
    end

    // Cache data & update byte_idx (sequential logic)
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            byte_idx <= 0; // Reset byte index on reset
            data_buf <= '0;
            s_axis_uart_ready <= 1'b0; // Reset ready signal on reset
        end else begin
            case (state)
                IDLE: begin
                    // Cache only when handshake is successful
                    if (s_axis_tvalid) begin
                        data_buf <= s_axis_tdata;
                        byte_idx <= '0;
                        s_axis_uart_ready <= 1'b0; // Not ready to send until the first byte is processed
                    end else
                        s_axis_tready <= 1'b1; // Ready to receive data
                end
  
                SEND_BYTE:
                    // If UART is busy, do not update byte_sent
                    if (!uart_busy) s_axis_uart_ready <= 1'b1; // Ready to send next byte
                    else s_axis_uart_ready <= 1'b0; // Not ready to send if UART is busy

                
                default: begin
                    s_axis_uart_ready <= 1'b0;
                end
            endcase
        end
    end

    // TODO: not sure what does this block do
    // start_byte is an internal signal and doesn't drive any other output
    // Generate a single-cycle start_byte pulse to drive uart_gen.
    /*
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            start_byte <= 1'b0;
            byte_idx <= 0; // Reset byte index on reset
        end else begin
            start_byte <= 1'b0;
            // From IDLE to SEND_BYTE, or at the end of each SEND_BYTE cycle
            if (state==IDLE     && next_state==SEND_BYTE) start_byte <= 1'b1;
            if (state==SEND_BYTE && next_state==SEND_BYTE && !uart_busy)
                start_byte <= 1'b1;
        end
    end*/

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

   