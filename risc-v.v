module riscv_core(
  //control signal
  input clk,
  input rst,
  //I.M. Signal
  input [31:0] ir_data, //Inst Read data
  output[31:0] i_addr,  //Inst addr
  //D.M. Signal
  input [31:0] dr_data, // Data M. Read data
  output[31:0] d_addr,  // Data addr= {rs1+imm_s}
  output[31:0] dw_data, // Data M. Write data=rs2_data
  output       d_we     // Data M. write enable=mem_write
);
  
  //Register File
  reg [31:0] pc;				// program counter
  reg [31:0] register[31:0];	// 32 gen registers[x0-x31]
  
  //Control logic signal
  reg [2:0] alu_op;
  reg reg_write;
  reg mem_write;
  reg alu_src;
  reg [1:0]pc_src;
  
  //alu signal
  reg [31:0] alu_result;
  
  //Reset
  
  //Instruction Decode Logic + Immediate value generation for diff Inst.
  wire [6:0] opcode=ir_data[6:0];	// Instruction opcode
  wire [4:0] rd=ir_data[11:7];		// Destination register
  wire [2:0] funct3=ir_data[14:12];	// Function code 
  wire [4:0] rs1=ir_data[19:15];	// source register 1
  wire [4:0] rs2=ir_data[24:20];	// source register 2
  wire [6:0] funct7=ir_data[31:25]; // Additiona function code.
  
  wire [31:0] imm_i={{20{ir_data[31]}},ir_data[31:20]};			                            // I-Type Imm value 
  wire [31:0] imm_s={{20{ir_data[31]}},ir_data[31:25],ir_data[11:7]};                               // S-Type Imm value
  wire [31:0] imm_b={{19{ir_data[31]}},ir_data[31],ir_data[7],ir_data[30:25],ir_data[11:8],1'b0};   // B-Type Imm value
  wire [31:0] imm_j={{11{ir_data[31]}},ir_data[31],ir_data[19:12],ir_data[20],ir_data[30:21],1'b0}; // J-Type Imm value
  wire [31:0] imm_u={ir_data[31:12],12'b0};		                                            // U-Type Imm value
  
  //Program Counter update Logic
  always@(posedge clk)
    begin
      if(rst)
        begin
        pc<=32'd0;	//Reset PC to 0;
        end
      else// if (ir_data)
        begin
          case(pc_src)
            2'b00:pc<=pc+4; 			      // Normal (default) increment [R/I/S]
            2'b01:pc<=pc+imm_b;			      // Branch
            2'b10:pc<=pc+imm_j;        // PC=PC_IMMJ	         // Jump [Jal]
            2'b11:pc<=alu_result;		      // pc=register[rd]=[pc+4]	 // Jump register [Jalr]
          endcase
        end
    end
  //Instruction Fetch Logic
  assign i_addr=pc;
  
  //Datapath connections [storing source reg data.]
  wire [31:0] rs1_data=register[rs1]; 		
  wire [31:0] rs2_data=register[rs2];		
  wire [31:0] alu_in2=alu_src?imm_i:rs2_data; //alu_src, will write logic in control unit
  
  //Data Memory Interface Logic
  assign d_addr={rs1+imm_s};
  assign dw_data=rs2_data;
  assign d_we=mem_write;
  
  //ALU Operation Logic
  always@(*)
    begin
      case(alu_op) //alu_op=f{funct7,func3} //will write logic in control unit

        3'b000:alu_result=rs1_data+alu_in2;				// ADD
        3'b001:alu_result=rs1_data-alu_in2;				// SUB 
        3'b010:alu_result=rs1_data&alu_in2;				// AND
        3'b011:alu_result=rs1_data*alu_in2;			        	// MUL
        3'b100:alu_result=rs1_data^alu_in2;				// XOR
        3'b101:alu_result=rs1_data<alu_in2?32'd1:32'd0;          	// SLT
        3'b110:alu_result=rs1_data<<alu_in2;				// SLL
        3'b111:alu_result=rs1_data>>alu_in2;				// SRL
      endcase
    end
  
  //Register File update Logic
  always@(posedge clk) // 
    begin
      register[0]=0;
      if(reg_write && rd!=0 ) //x0 is read only
        	register[rd]=alu_result;
    end
  
  //Control Logic + [control signal] 
  
  always@(*)
    begin
      reg_write=1'b0;
      mem_write=1'b0;
      alu_op=3'b000;
      alu_src=1'b0;
      pc_src=2'b00;
      
      case(opcode)
        7'b0110011:begin//R-Type
            reg_write=1'b1;
          case(funct3)
              3'b000:alu_op=(funct7==7'b000_0000)?3'b000:3'b001;	//ADD or SUB
              3'b001:alu_op=3'b110;		//SLL
              3'b100:alu_op=3'b100;		//XOR
              3'b101:alu_op=3'b111;		//SRL
              3'b110:alu_op=3'b011;	 	         //MUL
              3'b110:alu_op=3'b010;		//AND
          endcase
                    end
        7'b0010011:begin//I-Type
            reg_write=1'b1;
            alu_src=1'b1;
          case(funct3)
              3'b000:alu_op=3'b000;		//ADDI 
              3'b001:alu_op=3'b110;		//SLL
              3'b100:alu_op=3'b100;		//XORI
              3'b101:alu_op=3'b111;		//SRL
              3'b110:alu_op=3'b011;	 	//OR
              3'b110:alu_op=3'b010;		//AND
          endcase
                    end
        7'b0100011:begin//S-Type
            mem_write=1'b1;
            alu_src=1'b1;
            alu_op=3'b000; //ADD for address calculation.
                    end
        7'b1100011:begin//B-Type
          case(funct3)
            3'b000:pc_src=(rs1_data==rs2_data)?2'b01:2'b00;		//BEQ 
            3'b001:pc_src=(rs1_data!=rs2_data)?2'b01:2'b00;		//BNQ 
            3'b100:pc_src=(rs1_data<rs2_data)?2'b01:2'b00;		//BLT
          endcase
                    end
        7'b1101111:begin//J-Type
              pc_src=2'b10;
              //reg
              reg_write=1'b1;
              alu_result=pc+4;
                    end
         endcase
   end
  
endmodule


module tb;
  reg clk=0;
  reg rst=1;
  reg [31:0] ir_data; //Inst Read data
  reg [31:0] i_addr;  //Inst addr
  reg [31:0] dr_data; // Data M. Read data
  reg [31:0] d_addr;  // Data addr= {rs1+imm_s}
  reg [31:0] dw_data; // Data M. Write data=rs2_data
  reg       d_we;    // Data M. write enable=mem_write
  
  //Instruction memory
  reg [31:0] ins_mem [31:0];
  
  //Data memory
  reg [31:0] dt_mem [31:0];
  
  riscv_core RISC_0(.clk(clk),.rst(rst),.ir_data(ir_data),.i_addr(i_addr),.dr_data(dr_data),.d_addr(d_addr),.dw_data(dw_data),.d_we(d_we));
  
  always #5 clk=~clk;

  initial begin
    
      //Storing Instructions
      /*
      ins_mem[10]=32'b0000000_00100_00101_100_01100_1100011;	 //blt x5,  x4, 12   PC=PC+IMMB
      ins_mem[11]=32'b0000000_00000_11110_000_00111_0110011;	 //add x7, x30, x0   PC=PC+4
      ins_mem[12]=32'b0000000_00000_00000_000_10000_1100011;	 //beq x0,  x0, 16   PC=PC+IMMB
      ins_mem[13]=32'b0000000_00000_11101_000_00111_0110011;     //add x7, x29, x0   PC=PC+4
      */
      ins_mem[0]=32'b0000000_00101_00000_000_00101_0010011;       // addi x5, x0, 5
      ins_mem[1]=32'b0000000_00001_00000_000_00110_0010011;       // addi x6, x0, 1
      ins_mem[2]=32'b0000000_00101_00000_000_00111_0010011;       // addi x7, x0, 5
      ins_mem[3]=32'b0000000_00110_00111_000_10000_1100011;       // beq x7, x6, 16
      ins_mem[4]=32'b0000000_00110_00101_110_00101_0110011;       // mul x5, x5, x6
      ins_mem[5]=32'b0000000_00001_00110_000_00110_0010011;       // addi x6, x6, 1
      ins_mem[6]=32'b1_1111111000_1_11111111_00000_1101111;       // jal x0, -16
      ins_mem[7]=32'b0000000_00101_00000_010_00000_0100011;       // sw x5, 0(x0)
	  
      //Initialising Data Memory
      for(int i=0;i<32;i++)begin
        dt_mem[i]=0;
      end   

      //Stimulus
      #6 rst = 0;
    
  end 
  
  always @(negedge clk) ir_data = ins_mem[i_addr>>2]; 

  //Data Memory Read Write
  always @(negedge clk)begin
     if(d_we)begin
        dt_mem[d_addr>>2] = dw_data;	
     end
    dr_data = dt_mem[d_addr>>2];
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    #10000
    $finish;
  end
  
endmodule


