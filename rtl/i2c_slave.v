module i2c_slave(
	input scl,			//serial clock line
	inout sda			//serial data line
	);			
	
	parameter READ_ADDR=2'b00, SEND_ACK_1=2'b01, DATA_TRANS=2'b10, SEND_ACK_2=2'b11;		//FSM states	
	
	localparam SLAVE_ADDRESS=7'b1010111;	//address of slave
	
	//internal registers
	reg [1:0] state=READ_ADDR;				//current state
	reg [6:0] addr;							//received address
	reg rw;										//high for read, low for write
	reg [7:0] data_in=0;						//received data
	reg [7:0] data_out=8'b11001101;		//stored data
	reg sda_out=0;								//data to put on sda
	reg sda_enable=0;							//enable for sda
	reg sda_enable_2=1;						//enable for sda
	reg [2:0] count=7;						//general counter
	reg start=0;								//signal to start
	reg stop=1;									//signal to reset
	
	
	//check start and stop condition
	always@(sda) begin
		//start condition
		if(sda==0 && scl==1)begin
			start<=1;
			stop<=0;
		end
		
		//stop condition
		if(sda==1 && scl==1)begin
			start<=0;
			stop<=1;
		end
	end
	
	//generate state machine
	always@(posedge scl) begin
		if(start) begin
			case(state)
				READ_ADDR:begin
					if(count==0)begin
						sda_enable_2<=1;
						rw<=sda;
						state<=SEND_ACK_1;
					end
					else begin
						addr[count-1]<=sda;
						count<=count-1;
						state<=READ_ADDR;
					end
				end
				
				SEND_ACK_1:begin
					if(addr==SLAVE_ADDRESS) begin
						state<=DATA_TRANS;
						count<=7;
					end
				end
				
				DATA_TRANS:begin
					//read
					if(!rw) begin
						data_in[count]<=sda;
						if(count==0) state<=SEND_ACK_2;
						else begin
							count<=count-1;
							state<=DATA_TRANS;
						end
					end
					
					//write
					else begin
						if(count==0) state<=READ_ADDR;
						else begin
							count<=count-1;
							state<=DATA_TRANS;
						end
					end
				end
				
				SEND_ACK_2:begin
					state<=READ_ADDR;
					sda_enable_2<=0;
					count<=7;
				end
				
			endcase
		end
		else if(stop)begin
			state<=READ_ADDR;
			sda_enable_2<=1;
			count<=7;
		end
	end
	
	//logic for sda_enable
	always@(negedge scl) begin
		case(state)
			
			READ_ADDR: sda_enable<=0;
			
			SEND_ACK_1:begin
				//ACK
				if(addr==SLAVE_ADDRESS) begin
					sda_out<=0;
					sda_enable<=1;
				end
				//NACK
				else sda_enable<=0;
			end
			
			DATA_TRANS:begin
				//read
				if(!rw) sda_enable<=0;
				
				//write
				else begin
					sda_out<=data_out[count];
					sda_enable<=1;
				end
			end
			
			SEND_ACK_2:begin
				sda_out<=0;
				sda_enable<=1;
			end
			
		endcase
	end
	
	assign sda=(sda_enable && sda_enable_2)?sda_out:'bz;
	
endmodule 