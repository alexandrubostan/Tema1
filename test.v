`timescale 1ns / 1ps

// !!! Nu includeti acest fisier in arhiva !!!

module top;

reg         clk;
wire[23:0]  in_pix;
wire[5:0]   row, col;
wire        we;
wire[23:0]  out_pix;
wire        mirror_done;
wire        gray_done;
wire        filter_done;

process p(clk, in_pix, row, col, we, out_pix, mirror_done, gray_done, filter_done);
image i(clk, row, col, we, out_pix, in_pix);

initial begin
   clk = 0;
end

always #5 clk = !clk;

endmodule
