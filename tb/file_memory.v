// SPDX-License-Identifier: MIT

`timescale 1ns/1ns

module file_memory #(
    parameter firmware = "",
    parameter bitline = 16,
    parameter bitaddr = 8,
    parameter binary = 1
) (
    input                    clk,
    input                    en,
    input                    we,
    input  [bitaddr-1:0]     addr,
    input  [bitline-1:0]     din,
    output reg [bitline-1:0] dout
);
    reg [bitline-1:0] memory [0:(1 << bitaddr)-1];

    initial begin
        if (binary)
            $readmemb(firmware, memory);
        else
            $readmemh(firmware, memory);
    end

    always @(posedge clk) begin
        if (en) begin
            if (we)
                memory[addr] <= din;
            else
                dout <= memory[addr];
        end
    end
endmodule
