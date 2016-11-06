module proj(input  logic       clk,
				input  logic [3:0]     switches,
				input  logic [2:0] miso,
				output logic       mosi,
				output logic       sclk,
				output logic       ncs,
				output logic [7:0] led_array,
				output logic [4:0] w_grnd,
				output logic [4:0] w_vcc,
				output logic       done);
				
	logic [9:0] data;
	logic enable;

	adc_read ADCR(
		.clk(clk),
		.sclk(sclk),
		
		.mosi(mosi),
		.miso(miso),
		.ncs(ncs),
		.n_sel(switches[2:0]),
		.data(data),
		.enable(enable),
		.done(done)
	);
	
	always_ff@(posedge clk)
	begin	
		if(enable&done) enable<=0;
		else enable <=1;
	end
		
		
	assign led_array = (switches[3])?data[9:2]:0;
endmodule


module adc_read(input logic clk,
                output logic sclk,
				    output logic mosi,
					 output logic ncs,
					 input  logic [2:0] miso,
					 input  logic [2:0] n_sel,
					 output logic [9:0] data,
					 input logic enable, // edge
					 output logic done); // edge
					 
	logic [31:0] counter;
	logic [9:0] spi_register;
	logic [9:0] next_spi_reg;
	logic sclk_negedge;
	logic sclk_posedge;
	logic [31:0] next_counter;
	logic [9:0] next_spi_reg2;
	
	clock_mult CM(.clk(clk), .sclk(sclk));
	
	neg_edge NE(.clk(clk), .wave(sclk), .pulse(sclk_negedge));
	pos_edge PE(.clk(clk), .wave(sclk), .pulse(sclk_posedge));
	pos_edge PE2(.clk(clk), .wave(enable), .pulse(enable_posedge));
	
	always_ff @ (posedge clk)
	begin
		
		if (sclk_negedge)
		begin
			mosi <= spi_register[9];
		end
		
		counter <= next_counter;
		spi_register <= next_spi_reg;
		
		done <=  enable ? ( (counter >= 5'd16) ? 1'b1 : done) : 1'b0;
	
		
		if (counter == 5'd16 && ~done)
			data <= spi_register;
		
	end
	
	
	assign next_spi_reg2 =
					   sclk_posedge ? {spi_register[8:0], miso[n_sel[2:1]]} :
									   	spi_register;
	assign next_spi_reg = enable ? next_spi_reg2 : {3'b011, n_sel[0], 1'b1, 5'b0};
	
	assign next_counter = enable ? (sclk_posedge ? counter + 1 : counter) : 32'b0;
	
	assign ncs = ~(enable&~done);
	
endmodule

module neg_edge(input logic clk,
				    input logic wave,
				    output logic pulse);
	logic last_wave;
	
	initial last_wave=0;
	
	always_ff @ (posedge clk)
	begin
		last_wave = wave;
	end
	
	assign pulse = (last_wave != wave) && ~wave;
endmodule


module pos_edge(input logic clk,
				    input logic wave,
				    output logic pulse);
	logic last_wave;
	
	initial last_wave=0;
	
	always_ff @ (posedge clk)
	begin
		last_wave = wave;
	end
	
	assign pulse = (last_wave != wave) && wave;
endmodule
			
module counter5b(input logic clk,
					  input logic reset,
					  output logic [4:0] counter);
	
	initial counter=0;
	
	always_ff @ (posedge clk)
		if (reset)
			counter <= 5'b0;
		else
			counter <= counter + 1;
endmodule

module clock_mult(input logic clk,
					   output logic sclk);
	logic [4:0] counter;
	
	counter5b c5b(.clk(clk), .reset(1'b0), .counter(counter));
	
	assign sclk = counter[4];
endmodule