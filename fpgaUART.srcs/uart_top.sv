`timescale 1ns / 1ps

// This module is the top-level module for the UART design. 
module uart_top #(
    parameter int TDATA_WIDTH = 16                  // Data width from FFT
)(
    input logic clk,                                // Clock input
    input logic arstn,                              // Reset input
    input logic [TDATA_WIDTH - 1:0] s_axis_tdata,        // Data input for UART transmission
    input logic tvalid,                             // data valid signal from fft

    output logic uart_tx_output,
    output logic [7:0] data_aix_uart                // Data output to UART generator
);

logic uart_tx_busy, uart_start, uart_tx_complete, s_axis_tready;
logic [7:0] axi_data_out;                           // Data output from UART generator

uart_aix_interface aix_inst (
    // System inputs
    .clk(clk),
    .arstn(arstn),

    // Inputs from FFT
    .s_axis_tvalid(tvalid),
    .s_axis_tdata(s_axis_tdata),

    // Input from uart_gen
    .uart_busy(uart_tx_busy),
    .uart_tx_complete(uart_tx_complete),

    // outputs to uart_gen
    .s_axis_data_output(axi_data_out),                         // Processed 8-bit data to be sent to UART
    // TODO: check if the usage of tready is correct
    .uart_start(uart_start),
    .s_axis_tready(s_axis_tready)
);

// Instantiate the UART generator module
uart_gen uart_inst (
    .clk(clk),
    .arstn(arstn),
    .data_in(axi_data_out),                                     // data from AXI
    .start(uart_start),                                  // Start signal for transmission  
    
    .tx_busy(uart_tx_busy),
    .data_out(data_out),
    .tx_complete(uart_tx_complete), 
    
    .tx_output(tx_output)
);   

endmodule