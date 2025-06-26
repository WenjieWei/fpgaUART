`timescale 1ns / 1ps

module uart_aix_interface #(
    parameter int TDATA_WIDTH = 16,
    parameter int NUM_BYTES = (TDATA_WIDTH + 7) / 8,
    parameter int CLK_FREQ = 100000000,                 // 100MHz clock
    parameter int BAUD_RATE = 9600                      // Chose 9600 as baud rate
)(
    input logic clk,                                    // Clock input
    input logic arstn,                                  // Reset input

    // Inputs from FFT
    input logic s_axis_tvalid,                          // Valid signal for AXI stream
    input logic [TDATA_WIDTH - 1:0] s_axis_tdata,       // Data input from AXI stream

    // Input from uart_gen
    input logic uart_busy,                              // UART busy signal
    input logic uart_tx_complete,                       // UART transmission complete signal

    // Outputs to uart_gen
    output logic [7:0] s_axis_data_output,              // Processed 8-bit data to be sent to UART
    output logic uart_start,                            // Start signal for UART transmission
    output logic s_axis_tready                          // Ready signal for AXI interface
);

// Define AXI statemachine
typedef enum logic [1:0] { IDLE, SEND_BYTE } state_t;
state_t state, next_state;

logic [$clog2(NUM_BYTES):0] byte_idx;

// Flag to indicate if a word has been sent, in case tvalid does not clear after the word is sent
logic word_sent; 

// Status register (including asynchronous reset)
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    case (state)
        IDLE: 
            // tvalid indicates the upstream has a data word to send. 
            // need to consider if this is the previous already-sent word, or a new one.
            // If new word, start sending it. 
            // otherwise, wait until tvalid is cleared.
            if (s_axis_tvalid && !word_sent) 
                next_state = SEND_BYTE; // Transition to SEND_BYTE state
            else if (!s_axis_tvalid) begin
                next_state = IDLE; // Remain in IDLE state
                uart_start = 0; // Clear start signal
                byte_idx = 0; // Reset byte index
                word_sent = 0; // Reset word sent flag
            end

        SEND_BYTE:
            // If UART is busy, stay in SEND_BYTE state
            if (uart_busy) begin
                next_state = SEND_BYTE;
                uart_start = 0; // Do not start transmission if UART is busy
            end

            // If UART is not busy, it could be one of the following situations: 
            // 1. We have not sent anything yet, since the previous reset. 
            //      In this case, start the transmission of the first byte.
            //      do not increment byte index
            // 2. transmission of the current byte (not last) is complete and tx_complete is high
            // then we inspect the byte index to determine if we need to send another byte
            // if yes: 
            //      1) stay in SEND_BYTE state
            //      2) increment byte index and send the next byte
            // 3. UART transmitted all bytes and tx_complete is high
            // if yes: 
            //      1) go back to IDLE state
            //      2) reset byte index to 0
            
            else begin
                if (uart_tx_complete || s_axis_tvalid) begin
                    if (byte_idx < NUM_BYTES - 1) begin
                        if (uart_tx_complete) byte_idx = byte_idx + 1; // Increment byte index
                        next_state = SEND_BYTE; // Continue sending next byte
                        s_axis_data_output = s_axis_tdata[(byte_idx * 8) +: 8]; // Extract the next byte to send
                        uart_start = 1; // Set start signal for UART transmission
                    end else begin
                        next_state = IDLE; // All bytes sent, go back to IDLE
                        byte_idx = 0; // Reset byte index
                        uart_start = 0; // Clear start signal
                        word_sent = 1; // Indicate that a word has been sent
                    end
                end else begin
                    next_state = IDLE; // Return to IDLE to wait for new data
                end
            end
    endcase
end

assign s_axis_tready = (state == IDLE); // Ready to receive data when in IDLE state

endmodule
