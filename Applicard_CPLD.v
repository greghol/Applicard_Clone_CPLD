`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  Freed Consulting
// Engineer: Alex Freed
// 
// Create Date:    21:10:58 12/05/2008 
// Design Name: 
// Module Name:    pcpi_intf 
// Project Name: 
// Target Devices: XC9536
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 2.1
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module pcpi_intf(
		 
		 output reset_z80,
		 output NMI_z80,
		 output ROM_ce_n,
		 output toz80_oe_n,
		 output to65_oe_n,
		 output toz80_clk,
		 output to65_clk,

		 output RAM_ce_n,
 		 inout data_z80_0,
		 inout data_z80_7,				 
		 inout data_6502_7,
		 input [2:0]addr6502,
		 input [2:0]addr80,
		 input addr80_15,
		 input memtop, // active LOW due to 74HC00 used

		 output addr_16,
		 output addr_17,
		 output addr_18,		 
		 
		 input rw, 
		 input iosel, input memrq,
		 input devsel, 
		 input iorq, 

		 input rst_n,
		 input wr_z80,
		 input rd_z80,
		 input data_z80_1,
		 input data_z80_2,
		 input data_z80_3,		 
		 input data_z80_6		 
		 );

   
   reg 		data_rdy_to80;
   reg 		data_rdy_to6502=0;
   reg 		ROM_en;
   reg 		common_on;
   reg [2:0] 	bank;
   
   
   wire 	common_bank = common_on && addr80_15 && ~memtop;
   wire 	reset = ~rst_n || (~devsel && (addr6502[2:0] == 3'h5));
   wire 	cpu6502_reads_data =  (~devsel && (addr6502 == 0) ) || ~iosel;
   wire 	reading_io_z80 = ~rd_z80 && ~iorq;
   wire 	low_32k = ~addr80_15;   

`ifdef HAVE_NMI
   assign 	NMI_z80 = ~(~devsel && (addr6502[2:0] == 3'h7));
`else
   assign 	NMI_z80 = 1'b1;
`endif

   assign 	reset_z80 = ~reset;

   assign 	addr_16 = common_bank ? 0 : bank [0];
   
   assign 	addr_17 = ~(common_bank ? 0 : bank [1]);
   // addr 17 on 512K chip is CS1 on 128K - active high!

   assign 	addr_18 = common_bank ? 0 : bank [2]; // not connected on 128K
   
   assign 	ROM_ce_n = ~(~memrq && ROM_en && low_32k);
   assign 	RAM_ce_n = ~(~memrq && (~ROM_en || ~low_32k));

   wire 	wr_data_from_z80 = ((addr80 == 3'b000) && ~wr_z80 && ~iorq);
   assign 	to65_clk = ~wr_data_from_z80;
   
   wire 	wr_data_from_6502 = ~devsel && ~rw && (addr6502 == 3'h1);
   assign 	toz80_clk = ~wr_data_from_6502;
   assign 	to65_oe_n = ~cpu6502_reads_data;
   assign 	data_6502_7 = (~devsel && (addr6502 == 2) ) ? data_rdy_to80:
		(~devsel && (addr6502 == 3) ) ? data_rdy_to6502:  1'bz;

   wire 	port20 = (reading_io_z80 && (addr80 == 3'b001));
   wire 	port40 = (reading_io_z80 && (addr80 == 3'b010));
   assign 	toz80_oe_n = ~port20;
   assign 	data_z80_0 =  port40 ? data_rdy_to6502 : 1'bz;
   assign 	data_z80_7 =  port40 ? data_rdy_to80 : 1'bz;
   wire 	clr_z80_data = (~devsel && (addr6502 == 3'b000)) ||  reset;
   wire 	clr_6502_data =  port20 ||  reset;
   wire 	z80_io_wr = ~iorq && ~wr_z80;
   
   always @ (negedge wr_data_from_z80 or posedge clr_z80_data) begin
      if(clr_z80_data) begin
	 data_rdy_to6502 <= 0;
      end else begin
	 data_rdy_to6502 <= 1;
      end
   end

    always @ (negedge wr_data_from_6502 or  posedge clr_6502_data) begin
       if(clr_6502_data) begin
	  data_rdy_to80 <= 0;
       end else begin
	  data_rdy_to80 <= 1;
       end
    end
   

   always @(posedge z80_io_wr or posedge reset) begin
     if(reset)
       ROM_en <= 1;
     else if(addr80 == 3'b011)
       ROM_en <= data_z80_0;
   end

   always @(posedge z80_io_wr or posedge reset) begin
     if(reset) begin
	common_on <= 1;
	bank <= 3'b0;
     end    
 
     else if(addr80 == 3'b110) begin
	common_on <= ~data_z80_6;
	bank <= {data_z80_3, data_z80_2,data_z80_1};
     end
   end

endmodule