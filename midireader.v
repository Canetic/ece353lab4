/*
 *midireader.v
 *Contributors: Angus Mo, Timothy Shum, O-Dom Pin, Karl Shao
 */

module midireader(midi_in, rst_n, clk, LED_out);
	
	input	midi_in, rst_n, clk;
	output 	[7:0] LED_out;
	
	reg 	rxb0, rxb1;		//recieve bit registers
	wire	[7:0] buffer;	//buffer connection between reciever and fsm
	wire	[7:0] out;		//output to LEDs
	
	assign	LED_out = out;
	
	receiver	RXC(.clk(clk), .rst_n(rst_n), .rxb(rxb1), .data(buffer));
	fsm			LED_FSM(.clk(clk), .rst_n(rst_n), .buffer(buffer), .LED_out(out));
	
	
	//poll midi input using 2 registers to prevent metastablity
	always @(posedge clk) begin
		if(!rst_n) begin
			rxb0 <= 1'b1;
			rxb1 <= 1'b1;
		end
		else begin
			rxb0 <= midi_in;
			rxb1 <= rxb0;
		end
	end
	
endmodule

//receives and moves midi messages into registers
module receiver(clk, rst_n, rxb, data);

	input 	clk, rst_n, rxb;
	output	[7:0] data;
	
	wire	[11:0] cnt;				//counter for midi bits and timer
	reg		[11:0] cnt_nxt;
	reg		[1:0] state, state_nxt;	//state registers to hold state
	reg		[7:0] buffer;			//output from the reciever
	reg		data_in;				//input to the shift registers
	wire	[7:0] out;				//output from the shift registers
	
	assign	data = buffer;

	counter		TCNT0(.clk(clk), .rst_n(rst_n), .cnt_nxt(cnt_nxt), .cnt_out(cnt));
	shiftReg	SR0(.clk(clk), .rst_n(rst_n), .rxb(data_in), .data(out));
	
	always @(posedge clk) begin
		if(!rst_n) begin
			state <= 2'b0;
		end
		else begin
			state <= state_nxt;
		end
	end

	always @(*) begin
		buffer = 8'b0;					//initial output
		data_in = out[0];				//loop shift registers
		cnt_nxt[7:0] = cnt[7:0] + 1'b1;	//define next count
		cnt_nxt[11:8] = cnt[11:8];		//hold the byte count
		case(state)
		//poll the start bit
			2'b0: begin
				if(rxb == 1'b0) begin
					state_nxt = 2'b01;
				end
				else begin
					state_nxt = 2'b0;
					cnt_nxt = 12'b0;
				end
			end
		//wait until the middle of the start bit
			2'b01: begin
				if(cnt[7:0] < 8'd64) begin
					state_nxt = 2'b00;
				end
				else begin
					state_nxt = 2'b10;
					cnt_nxt[7:0] = 8'b0;
				end
			end
		//wait until the middle of each message bit
			2'b10: begin
				if(cnt[7:0] < 8'd128) begin
					state_nxt = 2'b10;
				end
				else begin
					state_nxt = 2'b11;
					cnt_nxt[7:0] = 8'b0;
					cnt_nxt[11:8] = cnt[11:8] + 1'b1;
					data_in = rxb;
				end
			end
		//store each bit until the shift register is full
			2'b11: begin
				if(cnt[11:8] != 4'd8) begin
					state_nxt = 2'b10;
				end
				else begin
					state_nxt = 2'b00;
					cnt_nxt = 12'b0;
					buffer = out;
				end
			end
			default: begin
				state_nxt = 2'b00;
				cnt_nxt = 12'b0;
				data_in = out[0];
				buffer = 8'b0;
			end
		endcase
	end
	
endmodule

module fsm(clk, rst_n, buffer, LED_out);
	
	input 	clk, rst_n; 
	input	[7:0] buffer;
	output	[7:0] LED_out;

	reg		[7:0] buffer_in;		//input to the memory
	reg 	[1:0] state, state_nxt;	//state register to hold state
	wire	[7:0] out;				//output to the LEDs

	assign LED_out = out;
	
	//memory registers to store the note byte
	memory	MEM0(clk, rst_n, buffer_in, out);
	
	always @(posedge clk) begin
		if(!rst_n) begin
			state <= 2'b0;
		end
		else begin
			state <= state_nxt;
		end
	end

	always @(*) begin
		buffer_in = 8'b0;;
		case(state)
		//poll for the start byte
			2'b00: begin
				if(buffer[7:4] == 4'h9) begin
					state_nxt = 2'b01;
				end
				else begin
					state_nxt = 2'b00;
				end
			end
		//wait until the note byte is recieved
			2'b01: begin
				if(buffer == 8'b0) begin
					state_nxt = 2'b01;
				end
				else begin
					state_nxt = 2'b10;
					buffer_in = buffer;
				end
			end
		//display the note until the off byte is recieved
			2'b10: begin
				buffer_in = out;
				if(buffer[7:4] == 4'h8) begin
					state_nxt = 2'b11;
				end
				else begin
					if(buffer[7:4] == 4'h9) begin
						state_nxt = 2'b01;
					end
					else begin
						state_nxt = 2'b10;
					end
				end
			end
		//keep displaying the note until after the note message is recieved
			2'b11: begin
				if(buffer == 8'b0) begin
					state_nxt = 2'b11;
					buffer_in = out;
				end
				else begin
					state_nxt = 2'b00;
				end
			end
			default: begin
				state_nxt = 2'b0;
			end
		endcase
	end

endmodule

//shift register to store the serial midi input
module shiftReg(clk, rst_n, rxb, data);
	
	input 	clk, rst_n, rxb;
	output	[7:0] data;
	
	reg		[7:0] buffer;
	
	assign 	data = buffer;
	
	always @(posedge clk) begin
		if(!rst_n) begin
			buffer <= 8'b0;
		end
		else begin
			buffer[7] <= rxb;
			buffer[6] <= buffer[7];
			buffer[5] <= buffer[6];
			buffer[4] <= buffer[5];
			buffer[3] <= buffer[4];
			buffer[2] <= buffer[3];
			buffer[1] <= buffer[2];
			buffer[0] <= buffer[1];
		end
	end
	
endmodule

//memory registers to store the note byte
module memory(clk, rst_n, data_in, data);
	
	input 	clk, rst_n;
	input	[7:0] data_in;
	output	[7:0] data;
	
	reg[7:0] buffer;
	assign	data = buffer;
	
	//hold incoming data
	always @(posedge clk) begin
		if(!rst_n) begin
			buffer <= 8'b0;
		end
		else begin
			buffer <= data_in;
		end
	end

endmodule

module counter(clk, rst_n, cnt_nxt, cnt_out);
	
	input 	clk, rst_n; 
	input	[11:0] cnt_nxt;
	output	[11:0] cnt_out;

	reg		[11:0] cnt;
	assign	cnt_out = cnt;
	
	//increment the counter by the next count value
	always @(posedge clk) begin
		if(!rst_n) begin
			cnt <= 8'b0;
		end
		else begin
			cnt <= cnt_nxt;
		end
	end
endmodule
