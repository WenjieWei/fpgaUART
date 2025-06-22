`timescale 1ns / 1ps

module uart_top_tb;
    logic clk, arstn;
    logic [15:0] data_in; // 16-bit data from fft
    logic tdata_valid; // Data valid signal from FFT
    logic uart_tx_output; // UART transmit output
    logic [7:0] data_out; // Data output to UART generator

    // Instantiate the DUT (uart_top)
    uart_top dut (
        .clk(clk),
        .arstn(arstn),
        .data_in(data_in),
        .tdata_valid(tdata_valid),
        .uart_tx_output(uart_tx_output),
        .data_out(data_out)
    );

    // Generate clock signal
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Testbench stimulus
    initial begin
        #2;
        arstn = 0;
        data_in = 16'b1010_0111_0010_0110; // Example AXI data
        tdata_valid = 0;

        // Reset the DUT
        #10 arstn = 1;

        // Send AXI data
        #10 tdata_valid = 1;
        #1000 tdata_valid = 0; // Hold valid for a while

        // Wait for transmission to complete
        #100000;

        $finish; // End simulation
    end
endmodule
