`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output reg[5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg[23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output mirror_done,		// semnaleaza terminarea actiunii de oglindire (activ pe 1)
	output gray_done,		// semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
	output filter_done);	// semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)
	
	`define MIRROR_START 0
	`define MIRROR_1 1
	`define MIRROR_2 2
	`define MIRROR_3 3
	`define MIRROR_FIN 4
	`define GRAYSCALE_START 5
	`define GRAYSCALE 6
	`define GRAYSCALE_FIN 7
	`define SHARPNESS_START 8
	`define FIRST_CACHE 9
	`define SHARPNESS 10
	`define SHIFT_ROW_1 11
	`define SHIFT_ROW_2 12
	`define READ_ROW 13
	`define SHARPNESS_FIN 14
	
	`define R_IN in_pix[23:16]
	`define G_IN in_pix[15:8]
	`define B_IN in_pix[7:0]
	`define R_OUT out_pix[23:16]
	`define G_OUT out_pix[15:8]
	`define B_OUT out_pix[7:0]
	
	// starile automatului
	reg[3:0] state, next_state;
	
	// variabile auxiliare pt. stoacare de pixeli in stadiul de mirror
	reg[23:0] aux_pix1, aux_pix2;
	
	// var. pt. actualizarea row si col
	reg[5:0] aux_row, aux_col;
	
	reg[7:0] min, max;
	
	// array pt. cachuirea a 3 randuri (este signed ca sa putem face operatii signed)
	// are 2 coloane in plus pentru calcul mai usor (marginile sunt 0).
	reg signed[8:0] c[2:0][65:0];
	
	reg[6:0] j;
	reg signed[11:0] k;
	
	// daca se ajunge in starea de *_FIN atunci operatia respectiva s-a incheiat
	assign mirror_done = state >= `MIRROR_FIN;
	assign gray_done = state >= `GRAYSCALE_FIN;
	assign filter_done = state >= `SHARPNESS_FIN;
	
	// partea secv
	always @(posedge clk) begin
		state <= next_state;
		
		row <= aux_row;
		col <= aux_col;
	end
	
	// partea combinationala
	always @(*) begin
		out_we = 0;
		
		case (state)
			`MIRROR_START: begin
				aux_row = 0;
				aux_col = 0;
				
				next_state = `MIRROR_1;
			end
			
			`MIRROR_1: begin
				aux_row = 63 - row;
				aux_pix1 = in_pix;
				
				next_state = `MIRROR_2;
			end
			
			`MIRROR_2: begin
				aux_row = 63 - row;
				aux_pix2 = in_pix;
				out_pix = aux_pix1;
				out_we = 1;
				
				next_state = `MIRROR_3;
			end
			
			`MIRROR_3: begin
				out_pix = aux_pix2;
				out_we = 1;
				
				next_state = `MIRROR_1;
				
				if(row < 31) 
					aux_row = row + 1;
				else if(col < 63) begin
					aux_row = 0;
					aux_col = col + 1;
				end else
					next_state = `MIRROR_FIN;
			end
			
			`MIRROR_FIN: next_state = `GRAYSCALE_START;
			
			`GRAYSCALE_START: begin
				aux_row = 0;
				aux_col = 0;
				
				next_state = `GRAYSCALE;
			end
			
			`GRAYSCALE: begin
				next_state = `GRAYSCALE;
				
				if (`R_IN > `G_IN)
					max = `R_IN > `B_IN ? `R_IN : `B_IN;
				else
					max = `G_IN > `B_IN ? `G_IN : `B_IN;
					
				if (`R_IN < `G_IN)
					min = `R_IN < `B_IN ? `R_IN : `B_IN;
				else
					min = `G_IN < `B_IN ? `G_IN : `B_IN;
				
				`R_OUT = 0;
				`B_OUT = 0;
				
				`G_OUT = (max + min) / 2;
				
				out_we = 1;

				if (col < 63) begin
					aux_col = col + 1;
				end else if (row < 63) begin
					aux_col = 0;
					aux_row = row + 1;
				end else
					next_state = `GRAYSCALE_FIN;
			end
			
			`GRAYSCALE_FIN: next_state = `SHARPNESS_START;
			
			`SHARPNESS_START: begin
				aux_row = 0;
				aux_col = 0;
				
				for(j = 0; j < 66; j = j + 1) begin
					c[0][j] = 0;
					c[1][j] = 0;
					c[2][j] = 0;
				end
				
				
				next_state = `FIRST_CACHE;
			end
			
			`FIRST_CACHE: begin
				next_state = `FIRST_CACHE;
				
				// primele 2 randuri se pun in ultimele 2 randuri ale lui c
				// primul rand este plin de 0
				c[row+1][col+1] = `G_IN;
				
				if (col < 63)
					aux_col = col + 1;
				else if (row < 1) begin
					aux_col = 0;
					aux_row = row + 1;
				end else begin
					aux_row = 0;
					aux_col = 0;
					next_state = `SHARPNESS;
				end
			end
			
			`SHARPNESS: begin
				next_state = `SHARPNESS;
				
				if (col < 63)
					aux_col = col + 1;
				else begin
					next_state = `SHIFT_ROW_1;
					aux_col = 0;
					
					if(row < 63)
						aux_row = row + 2;
					else
						next_state = `SHARPNESS_FIN;
				end
				
				k = c[1][col+1]*9 - c[0][col] - c[0][col+1] - c[0][col+2] - c[1][col] - c[1][col+2] - c[2][col] - c[2][col+1] - c[2][col+2];
				
				if(k > 255)
					`G_OUT = 255;
				else if(k < 0)
					`G_OUT = 0;
				else
					`G_OUT = k;
					
				out_we = 1;
			end
			
			`SHIFT_ROW_1: begin
				for(j = 1; j < 65; j = j + 1) begin
					c[0][j] = c[1][j];
				end
				
				next_state = `SHIFT_ROW_2;
			end
			
			`SHIFT_ROW_2: begin
				for(j = 1; j < 65; j = j + 1) begin
					c[1][j] = c[2][j];
				end
				
				next_state = `READ_ROW;
			end
			
			`READ_ROW: begin
				next_state = `READ_ROW;
				
				if(row == 0)
					c[2][col+1] = 0;
				else
					c[2][col+1] = `G_IN;
				
				if(col < 63)
					aux_col = col + 1;
				else begin
					next_state = `SHARPNESS;
					aux_col = 0;
					aux_row = row - 1;
				end
			end
			
			`SHARPNESS_FIN: begin
				next_state = `SHARPNESS_FIN;
			end
			
			default: next_state = `MIRROR_START;
		endcase
	end

endmodule
