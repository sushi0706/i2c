module i2c_master(
	input clk,							//main 100MHz clock
	input areset,						//asynchronous reset
	input [6:0] addr,					//address of slave device
	input [7:0] data_in,				//data to write
	input enable,						//enable for i2c master
	input rw,							//high for read, low for write
	output reg [7:0] data_out,		//output data after read
	output busy,						//high when busy
	output scl,							//serial clock line (actual i2c clock)
	inout sda							//serial data line (actual i2c data)
	);							
						
	parameter IDLE=3'b000, START=3'b001, ADDR=3'b010, READ_ACK_1=3'b011, DATA_TRANS=3'b100, WRITE_ACK=3'b101, READ_ACK_2=3'b110, STOP=3'b111;		//FSM state
	
	//internal registers
	reg [2:0] state=IDLE;		//current state
	reg [2:0] count=0;			//general counter
	reg [7:0] count_2=0;			//counter to generate i2c clock
	reg i2c_clk=0;					//400KHz i2c clock
	reg scl_en_clk=0;				//800KHz clock
	reg [7:0] count_3=0;			//counter to generate scl_en_clk
	reg scl_enable=0;				//enable for scl
	reg sda_enable=0;				//enable for sda
	reg sda_out;					//data to put on sda
	reg [7:0] saved_addr;		//input address
	reg [7:0] saved_data;		//input data

	
	//generate i2c clk
	always @(posedge clk) begin
		if(count_2==124) begin
			i2c_clk <= ~i2c_clk;
			count_2<=0;
		end
		else count_2<=count_2+1;
	end 
	
	//generate scl_en_clk
	always @(posedge clk) begin
		if(count_3==62) begin
			scl_en_clk <= ~scl_en_clk;
			count_3<=0;
		end
		else count_3<=count_3+1;
	end 
	
	//logic for scl_enable
	always@(negedge scl_en_clk, posedge areset) begin
		if(areset) scl_enable<=1'b0;
		else begin
			if((state==IDLE) || (state==START) || (state==STOP)) scl_enable<=1'b0;
			else scl_enable<=1'b1;
		end
	end 
	
	//genrate state machine
	always@(posedge i2c_clk, posedge areset) begin
		if(areset) state<=IDLE;
		else begin
			case(state) 
			
				IDLE:begin
					if(enable)	begin
						state<=START;
						saved_addr<={addr,rw};
						saved_data<=data_in;
					end
					else state<=IDLE;
				end
				
				START:begin
					state<=ADDR;
					count<=7;
				end
				
				ADDR:begin
					if(count==0) state<=READ_ACK_1;
					else begin
						count<=count-1;
						state<=ADDR;
					end
				end
				
				READ_ACK_1:begin
					//ACK
					if(sda==0) begin
						count<=7;
						state<=DATA_TRANS;
					end
					
					//NACK
					else state<=STOP;
				end
				
				DATA_TRANS:begin
					//read
					if(saved_addr[0]) begin
						data_out[count]<=sda;
						if(count==0) state<=WRITE_ACK;
						else begin
							count<=count-1;
							state<=DATA_TRANS;
						end
					end
					
					//write
					else begin
						if(count==0) state<=READ_ACK_2;
						else begin
							count<=count-1;
							state<=DATA_TRANS;
						end
					end
				end
				
				WRITE_ACK: state<=STOP;
				
				READ_ACK_2: begin
					if (sda==0 && enable==1) state <= IDLE;
					else state <= STOP;
				end
				
				STOP: state<=IDLE;
				
			endcase
		end
	end 
	
	//logic for sda_enable
	always@(negedge i2c_clk, posedge areset) begin
		if(areset) begin
			sda_out<=1;
			sda_enable<=1;
		end
		else begin
			case(state)
				
				START:begin
					sda_out<=0;
					sda_enable<=1;
				end
				
				ADDR:begin
					sda_out<=saved_addr[count];
					sda_enable<=1;
				end
				
				READ_ACK_1: sda_enable<=0;
				
				DATA_TRANS:begin
					//read
					if(saved_addr[0]) sda_enable<=0;
					
					//write
					else begin
						sda_out<=saved_data[count];
						sda_enable<=1;
					end
				end
				
				WRITE_ACK:begin
					sda_out<=0;
					sda_enable<=1;
				end
				
				READ_ACK_2:sda_enable<=0;
				
				STOP:begin
					sda_out<=1;
					sda_enable<=1;
				end
				
			endcase
		end
	end 
	
	assign scl=(scl_enable)?i2c_clk:1'b1;
	assign sda=(sda_enable)?sda_out:'bz;
	assign busy=(state==IDLE)?0:1;
	
endmodule 