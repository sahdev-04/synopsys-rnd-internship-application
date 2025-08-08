// 8X256 FIFO

module syn_fifo_8x256(input clk,rst,rd_en,wr_en,input [7:0]dt_in,output reg full,empty,output reg [7:0]dt_out);
	reg [7:0]mem[255:0];
	reg [7:0]rd_pt,wr_pt;
	integer count=0;
	integer i;
	always @(posedge clk)begin
		//rst logic
		if(rst)begin
			wr_pt = 0; rd_pt = 0; count = 0;full = 0;
			for(i=0;i<256;i=i+1)begin
			mem[i]=0;
			end 
		end
		else begin
			//full logic
			if(count==0)begin 
				empty = 1;
			end else begin 
				empty = 0;
			end	
			//empty logic
			if(count==256)begin 
				full = 1;
			end else begin 
				full = 0;
			end
			//write logic
			if(wr_en & ~full)begin
				mem[wr_pt] = dt_in;
				wr_pt = wr_pt + 1;
				count = count + 1;
		    end
			//read logic
			if(rd_en & ~empty)begin
				dt_out = mem[rd_pt];
				mem[rd_pt] = 0;
				rd_pt = rd_pt + 1;
				count = count - 1;
			end
		end
	end

endmodule

//testbench 

module tb();
	reg clk=0,rst=0,rd_en,wr_en;
	reg [7:0]dt_in;
	reg full,empty;
	reg [7:0]dt_out;
	
	syn_fifo_8x256 f0 (clk,rst,rd_en,wr_en,dt_in,full,empty,dt_out);
		
	//clk assignment
	always #5 clk = ~clk;
	
	initial begin
		reset();
		repeat(10)write();
		repeat(15)read();
		repeat(12)write();
		#10 $finish;
	end
	
	task reset;
		begin
			@(negedge clk);
			rst = 1;
			@(negedge clk);
			rst = 0;
		end
    endtask
	
	task write;
		begin 
			@(negedge clk);
			dt_in = $random;
			wr_en = 1;
			@(negedge clk);
			wr_en = 0;
		end
    endtask
	
	task read;
		begin
			@(negedge clk);
			rd_en = 1;
			@(negedge clk);
			rd_en = 0;
		end
	endtask
	
endmodule
