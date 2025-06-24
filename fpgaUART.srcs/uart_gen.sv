`timescale 1ns / 1ps

module uart_gen #(
    parameter CLK_FREQ = 100000000,     // 100MHz clock
    parameter BAUD_RATE = 9600          // Chose 9600 as the most common baud rate
)(
    input var logic clk,                // Clock input
    input var logic arstn,              // Reset input
    input var logic [7:0] data_in,      // Data input
    input var logic start,              // Start signal for transmission

    output var logic tx_output,         // Transmit output
    output var logic tx_busy,           // Transmission busy signal
    output var logic tx_complete,       // Transmission complete signal
    output var logic [7:0] data_out     // Data output
);

// UART baud rate generator
// Internal parameters for baud rate generation and couunters
localparam int BAUD_PERIOD = CLK_FREQ / BAUD_RATE;
logic [15:0] baud_counter; // Counter for baud rate generation
logic [3:0] bit_counter; // Counter for the number of bits transmitted
logic [7:0] tx_shift_reg; // Shift register for data transmission
logic baud_tick; // Baud tick signal, indicating when to sample the next bit when 1

// UART FSM definition
typedef enum logic [1:0] {
    IDLE, START, DATA, STOP
} uart_state_t;
uart_state_t state;

// State transition logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        state <= IDLE; // Reset to IDLE state
        data_out <= 8'b0; // Clear output data on reset
        tx_complete <= 1'b0; // Clear transmission complete flag
    end else begin
        case (state)
            IDLE: 
                if (start) begin
                    state <= START; // Transition to START state on start signal
                    tx_complete <= 1'b0; // Indicate transmission is complete
                end
            START:
                if (baud_tick) state <= DATA; // Transition to DATA state after start bit
            DATA: 
                if (bit_counter == 4'd7 && baud_tick)
                    state <= STOP; // If all 8 bits are sent, transition to STOP
                else if (baud_tick)
                    state <= DATA; // Remain in DATA state until all bits are sent
            STOP:           
                if (baud_tick) begin
                    state <= IDLE; // Transition back to IDLE after stop bit
                    data_out <= tx_shift_reg; // Output the transmitted data
                    tx_complete <= 1'b1; // Set transmission complete flag
                end

            default:  
                state <= IDLE; // Default case to handle unexpected states
        endcase
    end
end

// TX output logic
always_comb begin
    case (state)
        IDLE:  tx_output = 1'b1;
        START: tx_output = 1'b0;
        DATA:  tx_output = tx_shift_reg[0];
        STOP:  tx_output = 1'b1;
    endcase
end

// Baud tick generation logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        baud_counter <= 0;
        baud_tick <= 1'b0; // No tick on reset
    end else if (state != IDLE) begin
        if (baud_counter == BAUD_PERIOD - 1) begin
            baud_counter <= 0;
            baud_tick <= 1'b1; // Generate tick signal
        end else begin
            baud_counter <= baud_counter + 1;
            baud_tick <= 1'b0; // No tick signal until counter reaches period
        end
    end else begin
        baud_counter <= 0; // Reset counter when not busy
        baud_tick <= 1'b0; // No tick signal when not busy
    end
end

// Bit counter and baud rate counter logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn)
        bit_counter <= 0;  
    else if (baud_tick) begin
        if (state == DATA)
            bit_counter <= bit_counter + 1;
        else
            bit_counter <= 0; // Reset bit counter in other states
    end
end

// Shift register logic
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn)
        tx_shift_reg <= 0;
    else if (state == START)
        tx_shift_reg <= data_in;                    // Load data with start bit
    else if (state == DATA && baud_tick)
        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};  // Shift right for next bit
end

// Busy flag logic
always_comb begin
    if (!arstn)
        tx_busy = 1'b0; // Not busy on reset
    else
        tx_busy = (state != IDLE); // Busy if not in IDLE state
end
endmodule
