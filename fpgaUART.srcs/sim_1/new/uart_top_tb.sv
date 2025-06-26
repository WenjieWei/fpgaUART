`timescale 1ns / 1ps

module uart_top_tb;
    logic clk, arstn;
    logic [15:0] s_axis_tdata; // 16-bit data from fft
    logic tvalid; // Data valid signal from FFT
    logic uart_tx_output; // UART transmit output
    logic [7:0] data_aix_uart; // Data output to UART generator

    // Instantiate the DUT (uart_top)
    uart_top dut (
        .clk(clk),
        .arstn(arstn),
        .s_axis_tdata(s_axis_tdata),
        .tvalid(tvalid),
        .uart_tx_output(uart_tx_output),
        .data_aix_uart(data_aix_uart)
    );

    // Generate clock signal
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // toggle off tvalid when 

    // Testbench stimulus
    initial begin
        #2;
        arstn = 0;
        s_axis_tdata = 16'b1010_0111_0010_0110; // Example AXI data
        tvalid = 0;

        // Reset the DUT
        #10 arstn = 1;

        // Send AXI data
        #10 tvalid = 1;

        // Wait for 2,215us
        #2_215_500;
        tvalid = 0; // Clear tvalid

        #100;
        tvalid = 1; // Send another data word
        s_axis_tdata = 16'b1100_1010_0101_1101;

        $finish; // End simulation
    end
endmodule
