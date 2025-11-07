/*
	v1_0:完成pcie tx组包
*/
`default_nettype	wire
module	pcie_tx_fun
#(
	parameter		IMG_WIDTH			=	1920	,
	parameter		IMG_HEIGHT			=	1080	,
	parameter		DMA_ADDR_WIDTH		=	64		,
	parameter		VIDEO_DATA_WIDTH	=	24		,
	parameter		PCIE_DATA_WIDTH		=	256		,
	parameter		PPC					=	4		,
	parameter		PIXCEL_BYTES		=	2		,
	parameter		DMA_LEN				=	3840	
			
)
(
	input								i_pcie_clk			,
	input								i_pcie_rst_n		,

	//configure
	input	[DMA_ADDR_WIDTH-1:0]		i_dma_base_addr		,
	input	[DMA_ADDR_WIDTH-1:0]		i_dma_base_addr2	,
	input	[DMA_ADDR_WIDTH-1:0]		i_dma_base_addr3	,
	input	[DMA_ADDR_WIDTH-1:0]		i_dma_base_addr4	,
	input	[9:0]						i_dma_len			,
	input								i_dma_set_en		,
	output	[1:0]						o_dma_wr_index		,
	output								o_dma_wr_done		,
	input								i_start_tx_flag		/* synthesis PAP_MARK_DEBUG="true" */,	//开始标志
	output	[31:0]						o_check_data		,	//检查数据
	
	//dma_port
	input								i_dma_cmd_rdy		,
	output								o_dma_req			,
	output	[DMA_ADDR_WIDTH-1:0]		o_dma_addr			,
	output	[9:0]						o_dma_len			,
	input								i_dma_tx_done		/* synthesis PAP_MARK_DEBUG="true" */,
	

	//user_data
	input								i_video_clk			,
	input								i_video_rst_n		,
	input	[VIDEO_DATA_WIDTH*PPC-1:0]	i_video_data		,
	input								i_video_vs			,
	input								i_video_de			,
	

	//pcie_data
	output	[PCIE_DATA_WIDTH-1:0]		o_dma_rd_data		,
	input								i_dma_rd_en			

);
//***************parameter*************************************
parameter	IMG_SIZE	=	IMG_WIDTH*IMG_HEIGHT*PIXCEL_BYTES	;	//一帧总字节数
parameter	SEND_TIMES	=	IMG_SIZE/DMA_LEN					;	//一帧需要经过多少次dma发送
parameter	PACKET_LEN	=	DMA_LEN/PIXCEL_BYTES/PPC			;	//实际一次组包计数 
parameter	RD_MAX_TIME	=	DMA_LEN/PCIE_DATA_WIDTH*8			;	
//********************************wire_define*************************************
wire			w_wr_fifo_rst	;	//写fifo复位
wire			w_rd_fifo_rst	;	//读fifo复位
wire	[13:0]	wr_water_level	;	//fifo计数



//********************************reg_define*************************************
//打拍同步
reg							r_video_start_tx_flag_d0	;
reg							r_video_start_tx_flag_d1	;
			
//video时钟			
reg	[15:0]					r_wr_cnt					;
reg							r_line_req					;	//一行标志
reg							r_video_dma_req_d0			;
reg							r_video_dma_req_d1			;
reg							r_video_dma_req_d2			;
reg							r_video_vs					;
reg							r_video_vs_en				;
reg	[7:0]					r_video_vs_ext_cnt			;
reg							r_video_vs_rst				;
			
//pcie时钟			
reg							r_pci_line_req_d0			;
reg							r_pci_line_req_d1			;
reg							r_pci_line_req_d2			;
reg							r_dma_req					;	//dma请求
reg	[15:0]					r_rd_cnt					;
reg	[15:0]					r_frame_cnt					/* synthesis PAP_MARK_DEBUG="true" */;
reg							r_frame_done				/* synthesis PAP_MARK_DEBUG="true" */;
reg							r_frame_done_d0				;
reg							r_frame_done_d1				;
reg							r_frame_done_d2				;
reg	[1:0]					r_dma_index					/* synthesis PAP_MARK_DEBUG="true" */;
reg	[1:0]					r_dma_index_d0				;
reg	[DMA_ADDR_WIDTH-1:0]	r_dma_base_addr				;
reg	[DMA_ADDR_WIDTH-1:0]	r_dma_addr					;	//dma地址变化
reg	[9:0]					r_dma_len					;
reg	[31:0]					r_check_data				;	//发送索引 和帧完成信号
reg							r_pcie_vs_rst_d0			;
reg							r_pcie_vs_rst_d1			;
//********************************assign*************************************
assign	w_wr_fifo_rst	=	r_video_start_tx_flag_d1	;
assign	w_rd_fifo_rst	=	i_start_tx_flag				;
//********************************always*************************************
//video_clk时钟下打拍
always@(posedge i_video_clk)	begin
	r_video_start_tx_flag_d0	<=	i_start_tx_flag				;
	r_video_start_tx_flag_d1	<=	r_video_start_tx_flag_d0	;

	r_video_dma_req_d0			<=	r_dma_req					;
	r_video_dma_req_d1			<=	r_video_dma_req_d0			;
	r_video_dma_req_d2			<=	r_video_dma_req_d1			;

	r_video_vs					<=	i_video_vs					;

end

//扩展vs上升沿脉冲
always@(posedge i_video_clk)	begin
	if(!i_video_rst_n)	
		r_video_vs_en	<=	1'd0	;
	else	if(r_video_vs_ext_cnt == 15 && r_video_vs_en)
		r_video_vs_en	<=	1'd0	;
	else	if(i_video_vs && ~r_video_vs)
		r_video_vs_en	<=	1'd1	;
	else
		r_video_vs_en	<=	r_video_vs_en	;
end

always@(posedge i_video_clk)	begin
	if(!i_video_rst_n)	begin
		r_video_vs_rst		<=	1'd0	;
		r_video_vs_ext_cnt	<=	'd0		;
	end
	else	if(r_video_vs_ext_cnt == 15 && r_video_vs_en)	begin
		r_video_vs_rst		<=	1'd0	;
		r_video_vs_ext_cnt	<=	'd0		;
	end
	else	if(r_video_vs_en)	begin
		r_video_vs_ext_cnt	<=	r_video_vs_ext_cnt + 1'b1;
		r_video_vs_rst		<=	1'd1	;
	end
	else	begin
		r_video_vs_ext_cnt	<=	r_video_vs_ext_cnt	;
		r_video_vs_rst		<=	r_video_vs_rst		;	
	end
end



//pcie时钟下打拍
always@(posedge i_pcie_clk)	begin
	r_pci_line_req_d0	<=	r_line_req					;
	r_pci_line_req_d1	<=	r_pci_line_req_d0			;
	r_pci_line_req_d2	<=	r_pci_line_req_d1			;
	
	r_frame_done_d0		<=	r_frame_done				;
	r_frame_done_d1		<=	r_frame_done_d0				;
	r_frame_done_d2		<=	r_frame_done_d1				;

	r_pcie_vs_rst_d0	<=	r_video_vs_rst				;
	r_pcie_vs_rst_d1	<=	r_pcie_vs_rst_d0			;

end


//写入数据计数 是否写入一包DMA长度的数据
always@(posedge i_video_clk)	begin
	if(!i_video_rst_n || r_video_vs_rst || r_video_start_tx_flag_d1 == 0)
		r_wr_cnt	<=	'd0	;
	else	if(i_video_de && r_wr_cnt == PACKET_LEN-1)
		r_wr_cnt	<=	'd0	;
	else	if(i_video_de)
		r_wr_cnt	<=	r_wr_cnt + 1'b1;
	else
		r_wr_cnt	<=	r_wr_cnt;
end

//一行请求标志
always@(posedge i_video_clk)	begin
	if(!i_video_rst_n || r_video_vs_rst || r_video_start_tx_flag_d1 == 0)
		r_line_req	<=	'd0	;
	else	if(r_video_dma_req_d2)
		r_line_req	<=	'd0	;
	else	if(i_video_de && r_wr_cnt == PACKET_LEN-1)
		r_line_req	<=	'd1	;
	else
		r_line_req	<=	r_line_req	;
end


//发起dma请求
always@(posedge i_pcie_clk)	begin
	if(!i_pcie_rst_n)
		r_dma_req	<=	1'd0	;
	else	if(r_dma_req && r_pci_line_req_d2 == 0)
		r_dma_req	<=	1'd0	;
	else	if(r_pci_line_req_d2 && i_dma_cmd_rdy)
		r_dma_req	<=	1'd1	;
	else
		r_dma_req	<=	r_dma_req	;
end


//读出数据计数 统计是否读出一包
always@(posedge i_pcie_clk)	begin
	if(!i_pcie_rst_n)
		r_rd_cnt	<=	'd0	;
	else	if(i_dma_rd_en && r_rd_cnt == RD_MAX_TIME-1)
		r_rd_cnt	<=	'd0	;
	else	if(i_dma_rd_en)
		r_rd_cnt	<=	r_rd_cnt + 1'b1	;
	else
		r_rd_cnt	<=	r_rd_cnt;
end

//统计是否发送一帧
always@(posedge i_pcie_clk)	begin
	if(!i_pcie_rst_n || r_pcie_vs_rst_d1 || i_start_tx_flag == 0)
		r_frame_cnt	<=	'd0	;
	else	if(i_dma_tx_done && r_frame_cnt == SEND_TIMES-1)
		r_frame_cnt	<=	'd0	;
	else	if(i_dma_tx_done)
		r_frame_cnt	<=	r_frame_cnt + 1'b1;
	else
		r_frame_cnt	<=	r_frame_cnt;
end

//帧完成标志
always@(posedge i_pcie_clk)	begin
	if(!i_pcie_rst_n || i_start_tx_flag == 0)
		r_frame_done	<=	1'd0	;
	else	if(i_dma_tx_done && r_frame_cnt == SEND_TIMES-1)
		r_frame_done	<=	1'd1	;
	else
		r_frame_done	<=	1'd0	;
end


//帧索引 切换地址
always@(posedge    i_pcie_clk)    begin
    if(!i_pcie_rst_n || i_start_tx_flag == 0)
		r_dma_index	<=	'd0	;
	else	if(r_frame_done)
		r_dma_index	<=	r_dma_index + 1'b1;
	else
		r_dma_index	<=	r_dma_index;
end

//当前写入的帧数
always@(posedge    i_pcie_clk)    begin
    if(!i_pcie_rst_n || i_start_tx_flag == 0)
		r_dma_index_d0	<=	'd0;
	else	if(r_frame_done)
		r_dma_index_d0	<=	r_dma_index;
	else
		r_dma_index_d0	<=	r_dma_index_d0;
end


//基地址切换
always@(posedge    i_pcie_clk)    begin
    if(!i_pcie_rst_n)
		r_dma_base_addr	<=	'd0	;
	else	if(i_start_tx_flag == 0)
		r_dma_base_addr	<=	i_dma_base_addr	;
	else	if(r_frame_done_d0)	begin
		case(r_dma_index)
			'd0	:		r_dma_base_addr	<=	i_dma_base_addr				;
			'd1	:		r_dma_base_addr	<=	i_dma_base_addr2 	        ;
			'd2	:		r_dma_base_addr	<=	i_dma_base_addr3 	        ;
			'd3	:		r_dma_base_addr	<=	i_dma_base_addr4 	        ;
			default	:	r_dma_base_addr	<=	i_dma_base_addr				;
		endcase
	end
end


//dma地址累加
always@(posedge    i_pcie_clk)    begin
    if(!i_pcie_rst_n)
		r_dma_addr	<=	'd0	;
	else	if(i_start_tx_flag == 0)
		r_dma_addr	<=	i_dma_base_addr	;
	else	if(i_dma_set_en)
		r_dma_addr	<=	i_dma_base_addr	;
	else	if(r_frame_done_d1 || r_pcie_vs_rst_d1)	//复位 或者     发送完成  r_frame_done_d1
		r_dma_addr	<=	r_dma_base_addr	;    //r_dma_base_addr
	else	if(i_dma_tx_done)
		r_dma_addr	<=	r_dma_addr + DMA_LEN	;
	else
		r_dma_addr	<=	r_dma_addr	;
end


//dma长度配置
always@(posedge    i_pcie_clk)    begin
    if(!i_pcie_rst_n)
		r_dma_len	<=	'd0	;
	else	if(i_dma_set_en)
		r_dma_len	<=	i_dma_len	;
	else
		r_dma_len	<=	r_dma_len	;
end


//发送 索引 和 完成信号
always@(posedge    i_pcie_clk)    begin
    if(!i_pcie_rst_n)
		r_check_data	<=	'd0	;
	else	if(r_frame_done_d0)
		r_check_data	<=	{29'd0,r_dma_index_d0,1'd1}	;
	else
		r_check_data	<=	{29'd0,r_check_data[2:1],1'd0}	;
end



//***************端口输出*************************************
assign	o_check_data	=	r_check_data	;
assign	o_dma_wr_index	=	r_dma_index_d0	;
assign	o_dma_wr_done	=	r_frame_done	;
assign	o_dma_req		=	r_dma_req		;
assign	o_dma_addr		=	r_dma_addr		;
assign	o_dma_len		=	r_dma_len		;





//***************fifo*************************************
video_buffer video_buffer_inst (
  .wr_clk			(i_video_clk		),                    // input
  .wr_rst			(~w_wr_fifo_rst		),                    // input
  .wr_en			(i_video_de			),                    // input
  .wr_data			(i_video_data		),                    // input 
  .wr_full		    (),                  					  // output
  .wr_water_level	(wr_water_level		),    				  // output 
  .almost_full		(almost_full		),         			  // output
  
  .rd_clk			(i_pcie_clk			),                    // input
  .rd_rst			(~w_rd_fifo_rst		),                    // input
  .rd_en			(i_dma_rd_en		),                    // input
  .rd_data			(o_dma_rd_data		),                 	  // output 
  .rd_empty			(rd_empty			),                	  // output
  .rd_water_level	(w_rd_water_level	),    				  // output 
  .almost_empty		(almost_empty		)        		   	  // output
);




endmodule

















