`timescale 1ns / 1ps

// This module is the top-level module for the UART design. 
module uart_top #(
)(
    input var logic clk,                // Clock input
    input var logic arstn,              // Reset input
    input var logic [7:0] data_in,      // Data input
    input var logic start,              // Start signal for transmission

    output var logic tx_output,         // Transmit output
    output var logic tx_busy,           // Transmission busy signal
    output var logic [7:0] data_out     // Data output
);

// Instantiate the UART generator module
uart_gen uart_inst (
    .clk(clk),
    .arstn(arstn),
    .data_in(data_in),
    .start(start),
    .tx_output(tx_output),
    .tx_busy(tx_busy),
    .data_out(data_out)
);   
endmodule
