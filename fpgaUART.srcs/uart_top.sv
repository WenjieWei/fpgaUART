`timescale 1ns / 1ps

// This module is the top-level module for the UART design. 
module uart_top #(
    parameter int TDATA_WIDTH = 16                  // Data width from FFT
)(
    input logic clk,                                // Clock input
    input logic arstn,                              // Reset input
    input logic [TDATA_WIDTH - 1:0] data_in,        // Data input for UART transmission
    input logic tdata_valid,                        // data valid signal from fft

    output logic uart_tx_output,
    output logic [7:0] data_out                     // Data output to UART generator
);

logic uart_tx_busy, uart_start;
logic [7:0] axi_data_out;                           // Data output from UART generator

uart_axi_interface uart_axi_inst (
    // System inputs
    .clk(clk),
    .arstn(arstn),

    // Inputs from FFT
    .s_axis_tvalid(tdata_valid),
    .s_axis_tdata(data_in),

    // Input from uart_gen
    .uart_busy(uart_tx_busy),

    // outputs to uart_gen
    .uart_tx(axi_data_out),                         // Processed 8-bit data to be sent to UART
    // TODO: check if the usage of tready is correct
    .s_axis_tready(uart_start)                      // Start signal for UART transmission
);

// Instantiate the UART generator module
uart_gen uart_inst (
    .clk(clk),
    .arstn(arstn),
    .data_in(axi_data_out),                                     // data from AXI
    .start(start),                                  // Start signal for transmission  
    
    .tx_busy(uart_tx_busy),
    .data_out(data_out),
    
    .tx_output(tx_output)
);   

endmodule
