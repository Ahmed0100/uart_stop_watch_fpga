module uart_stopwatch_test
(
	input clk,reset_n,
	input send_up,send_go,send_clr, send_pause,
	input rx,
	output tx,
	output [7:0] sseg,
	output [3:0] sel
);

	reg rd_uart;
	wire rx_empty;
	wire[7:0] rd_data;
	reg clr; //clr=1 is clear
	reg up_reg=1,up_nxt; //up=1 is upward
	reg go_reg=0,go_nxt; //go=1 is play
	reg[7:0] wr_data_reg,wr_data_nxt;
	wire[4:0] in0,in1,in2,in3,in4,in5;
	reg wr_uart_nxt,wr_uart_reg;
	reg[7:0] displaytime[5:0];
	wire send_up_tick,send_go_tick,send_clr_tick,send_pause_tick;
	reg[2:0] index=0,index_nxt; //index to determine what wr_data will be written to UART. This will be the index for the register file
	reg lock=0,lock_nxt; //this will stay at "1' until all necessary wr_data is transmitted
	db_fsm m1
	(
		.clk(clk),
		.reset_n(reset_n),
		.sw(!send_up),
		.db_level(),
		.db_tick(send_up_tick)
   );
	db_fsm m2
	(
		.clk(clk),
		.reset_n(reset_n),
		.sw(!send_go),
		.db_level(),
		.db_tick(send_go_tick)
   );
	db_fsm m3
	(
		.clk(clk),
		.reset_n(reset_n),
		.sw(!send_clr),
		.db_level(),
		.db_tick(send_clr_tick)
   );
	db_fsm m4
	(
		.clk(clk),
		.reset_n(reset_n),
		.sw(!send_pause),
		.db_level(),
		.db_tick(send_pause_tick)
   );
	stop_watch stopwatch_inst
	(   
		.clk(clk),
		.reset_n(reset_n),
		.up(up_reg),
		.go(go_reg),
		.clr(clr), // up-> 1:Count up 0:Count down    go->1:play 0:pause    clr-->back to 0.00.0
		.in0(in0),
		.in1(in1),
		.in2(in2),
		.in3(in3),
		.in4(in4),
		.in5(in5)
   );
	disp_hex_mux disp_inst
	(
		.clk(clk),
		.reset_n(reset_n),
		.in_0({1'b0,in0}),
		.in_1({1'b0,in1}),
		.in_2({1'b0,in2}),
		.in_3({1'b0,in3}),
		.sseg(sseg),
		.sel(sel)
   );
	
	uart #(.DBIT(8),.SB_TICK(16),.DVSR(326),.DVSR_WIDTH(9),.FIFO_ADDR_WIDTH(4),
	.FIFO_DATA_WIDTH(8)) uart_inst
	(
		.clk(clk),
		.reset_n(reset_n),
		.rd_uart(rd_uart),
		.wr_uart(wr_uart_reg),
		.wr_data(wr_data_reg),
		.rx(rx),
		.tx(tx),
		.rd_data(rd_data),
		.rx_empty(rx_empty),
		.tx_full()
    );
	 always @(posedge clk or negedge reset_n)
	 begin
		if(~reset_n)
		begin
			up_reg <= 1;
			go_reg <= 0;
			lock<=0;
			index<=0;
//			wr_uart_reg <= 0;
//			wr_data_reg <= 0; 
		end
		else
		begin
			go_reg <= go_nxt;
			up_reg <= up_nxt;
			lock<=lock_nxt;
			index<=index_nxt;
//			wr_data_reg <= wr_data_nxt;
//			wr_uart_reg <= wr_uart_nxt;
		end
	 end
	 /*
	 always @(*)
	 begin
		wr_data_nxt = wr_data_reg;
		wr_uart_nxt = 0;
		if(send_clr_tick)
		begin
			wr_uart_nxt=1;
			wr_data_nxt =  8'h43;
		end
		else if(send_go_tick)
		begin
			wr_uart_nxt=1;
			wr_data_nxt = 8'h47 ;
		end
		else if(send_pause_tick)
		begin
			wr_uart_nxt=1;
			wr_data_nxt = 8'h50 ;
		end
		else if(send_up_tick)
		begin
			wr_uart_nxt=1;
			wr_data_nxt= 8'h55;
		end
	 end
	*/
	 always @(*)
	 begin
		up_nxt=up_reg;
		go_nxt=go_reg;
		clr=0;
		rd_uart=0;
		lock_nxt=lock;
		index_nxt=index;
		wr_uart_reg = 0;
		wr_data_reg = 0;
		if(!rx_empty) begin
			if(rd_data == 8'h43 || rd_data == 8'h63)
			begin
				clr=1;
				up_nxt = 1;
			end
			else if(rd_data == 8'h47 || rd_data == 8'h67)
			begin
				go_nxt = 1;
			end
			else if(rd_data ==8'h50 || rd_data == 8'h70)
			begin
				go_nxt=0;
			end
			else if(rd_data == 8'h55 || rd_data == 8'h75)
			begin
				up_nxt = !up_reg;
			end
			else if(rd_data==8'h52 || rd_data==8'h72) begin //r or R transmits current time to UART tx
				lock_nxt=1;
				index_nxt=0;
			end
			rd_uart=1;
		end

		if(lock) begin
			wr_data_reg=displaytime[index];
			wr_uart_reg=1;
			if(index==5) lock_nxt=0; //finish transmitting all data btyes
			else index_nxt=index+1;
		end
	 end

	 always @* begin //
		displaytime[0]={4'h3,in3[3:0]};//minutes
		displaytime[1]=8'h3a; //":"
		displaytime[2]={4'h3,in2[3:0]}; //second-digit of seconds
		displaytime[3]={4'h3,in1[3:0]}; //first-digit of seconds
		displaytime[4]=8'h3a; //":"
		displaytime[5]={4'h3,in0[3:0]};	//decimal or the 100ms
	 end
 
endmodule