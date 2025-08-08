// 8x256 RAM Module

module RAM_8x256(input CLK, RST, RD_EN, WR_EN, input [7:0] RD_AD, WR_AD, WR_DT, output reg [7:0] RD_DT);
	reg [7:0] mem [255:0];
	integer i;
	
	always @(posedge CLK) begin
		if (RST) begin         //----------RESET  LOGIC
			for(i=0;i<256;i++) begin
				mem[i] = 0;
			end
		end
		
		else begin
			if (WR_EN) begin   //----------WRITE  LOGIC
				mem[WR_AD] = WR_DT;
			end
			
			if (RD_EN) begin   //----------READ   LOGIC
				RD_DT = mem[RD_AD];
			end
		end
	end

endmodule

// Testbench 

module testbench();
	reg CLK=0, RST=0, RD_EN=0, WR_EN=0;
	reg [7:0] RD_AD, WR_AD, WR_DT;
	wire [7:0] RD_DT;
	
	RAM_8x256 m0(CLK, RST, RD_EN, WR_EN, RD_AD, WR_AD, WR_DT, RD_DT);
	
	always #5 CLK = ~CLK;

	task rst;
		begin
			@ (negedge CLK);
			RST = 1;
			@ (negedge CLK);
			RST = 0;
		end
    endtask

	task write;
		begin 
			@(negedge CLK);
			WR_AD = $random;
			WR_DT = $random;
			WR_EN = 1;
			@(negedge CLK);
			WR_EN = 0;
		end
    endtask
	
	task read;
		begin 
			@(negedge CLK)
			RD_AD = $random;
			RD_EN = 1;
			@(negedge CLK);
			RD_EN = 0;
		end
    endtask

	initial begin
		rst();
		repeat(5)write();
		repeat(5)read();
		#10 $finish;
	end

endmodule