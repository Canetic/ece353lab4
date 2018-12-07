module midireader(midi_in, rst_n, clk, LED_out);
	
	input	midi_in, rst_n, clk;
	output 	[7:0] LED_out, out_test;
	
	reg 	rxb;			//recieve bit
	wire	[7:0] buffer;	//buffer connection between reciever and fsm
	
	assign	LED_out = buffer;
	
	reciever	RXC(.clk(clk), .rst_n(rst_n), .rxb(rxb), .data(buffer));
	
	//poll midi input
	always @(posedge clk) begin
		if(!rst_n) begin
			rxb <= 1'b1;
		end
		else begin
			rxb <= midi_in;
		end
	end
	
endmodule

//recieves and moves midi messages into registers
module reciever(clk, rst_n, rxb, data);

	input 	clk, rst_n, rxb;
	output	[7:0] data;
	
	wire	[11:0] cnt;				//counter for midi bits and timer
	reg		[11:0] cnt_nxt;
	reg		[1:0] state, state_nxt;
	wire	[7:0] buffer;			//buffer holds midi bytes
	reg		[7:0] buffer_in;		//input to the buffer registers
	reg		data_in;				//input to the shift registers
	wire	[7:0] out;				//output from the shift registers
	
	assign	data = buffer;

	counter		TCNT0(.clk(clk), .rst_n(rst_n), .cnt_nxt(cnt_nxt), .cnt_out(cnt));
	shiftReg	SR0(.clk(clk), .rst_n(rst_n), .rxb(data_in), .data(out));
	bufferReg	DATA_REG0(.clk(clk), .rst_n(rst_n), .data_in(buffer_in), .data(buffer));
	
	always @(posedge clk) begin
		if(!rst_n) begin
			state <= 2'b0;
		end
		else begin
			state <= state_nxt;
		end
	end

	always @(*) begin
		buffer_in = buffer;
		data_in = out[0];
		cnt_nxt[7:0] = cnt[7:0] + 1'b1;
		cnt_nxt[11:8] = cnt[11:8];
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
					buffer_in = out;
				end
			end
			default: begin
				state_nxt = 2'b00;
				cnt_nxt = 12'b0;
				data_in = out[0];
				buffer_in = 8'b0;
			end
		endcase
	end
	
endmodule

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

module bufferReg(clk, rst_n, data_in, data);
	
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
