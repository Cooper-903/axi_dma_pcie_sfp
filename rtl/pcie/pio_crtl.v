/*
	v1_0:pio控制
*/
module	pio_crtl
(
	input					pcie_clk			/* synthesis PAP_MARK_DEBUG="true" */,
	input					rst_n				,

	//crtl
	output					start_flag			/* synthesis PAP_MARK_DEBUG="true" */,
    output                  set_dma_config_en   /* synthesis PAP_MARK_DEBUG="true" */,
	output	[63:0]			o_ch0_base_addr		/* synthesis PAP_MARK_DEBUG="true" */,
	output	[63:0]			o_ch0_base_addr2    /* synthesis PAP_MARK_DEBUG="true" */,
	output	[63:0]			o_ch0_base_addr3	/* synthesis PAP_MARK_DEBUG="true" */,
	output	[63:0]			o_ch0_base_addr4	/* synthesis PAP_MARK_DEBUG="true" */,
    input                   i_wr_frame_done     /* synthesis PAP_MARK_DEBUG="true" */,
    input   [1:0]           i_wr_index          /* synthesis PAP_MARK_DEBUG="true" */,
	//
	input					pio_wr_en			/* synthesis PAP_MARK_DEBUG="true" */,
	input	[9:0]			pio_wr_addr			/* synthesis PAP_MARK_DEBUG="true" */,
	input	[31:0]			pio_wr_data			/* synthesis PAP_MARK_DEBUG="true" */,
	
	//
	input					pio_rd_en			/* synthesis PAP_MARK_DEBUG="true" */,
	input	[9:0]			pio_rd_addr			/* synthesis PAP_MARK_DEBUG="true" */,
	output	[31:0]			pio_rd_data		    /* synthesis PAP_MARK_DEBUG="true" */

);
//------------------寄存器----------------------------
parameter       WR_FRAME_DONE    =    9'h140    ;
parameter       DMA_ADDR_L  	 =    9'h050    ;
parameter       DMA_ADDR_H	   	 =    9'h054    ;    //
parameter       DMA_ADDR1_L  	 =    9'h020    ;
parameter       DMA_ADDR1_H	   	 =    9'h024    ;    //
parameter       DMA_ADDR2_L  	 =    9'h040    ;
parameter       DMA_ADDR2_H	   	 =    9'h044    ;    //
parameter       DMA_ADDR3_L  	 =    9'h030    ;
parameter       DMA_ADDR3_H	   	 =    9'h034    ;    //
parameter		DMA_SET_EN		 =	  9'h060	;
//------------------reg------------------------------
reg				r_start_flag			;
reg				r_set_dma_config_en     ;
reg		[31:0]  r_pio_rd_data           ;
reg             r_wr_frame_done         ;
reg		[63:0]	r_ch0_base_addr			/* synthesis PAP_MARK_DEBUG="true" */;
reg		[63:0]	r_ch0_base_addr2		/* synthesis PAP_MARK_DEBUG="true" */;
reg		[63:0]	r_ch0_base_addr3		/* synthesis PAP_MARK_DEBUG="true" */;
reg		[63:0]	r_ch0_base_addr4		/* synthesis PAP_MARK_DEBUG="true" */;

//用户端
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_start_flag	<=	1'd0	;
	else	if(pio_wr_en && pio_wr_addr == 0 && pio_wr_data == 32'hffffffe5)	//开启
		r_start_flag	<=	1'd1	;
	else	if(pio_wr_en && pio_wr_addr == 0 && pio_wr_data == 32'hffffff00)	//关闭
		r_start_flag	<=	1'd0	;
	else
		r_start_flag	<=	r_start_flag	;
end

//内核
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_set_dma_config_en	<=	1'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_SET_EN && pio_wr_data == 32'h00000001)	//开启
		r_set_dma_config_en	<=	1'd1	;
	else
		r_set_dma_config_en	<=	1'd0	;
end


//低32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr[31:0]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR_L)
		r_ch0_base_addr[31:0]	<=	pio_wr_data	;
	else
		r_ch0_base_addr[31:0]	<=	r_ch0_base_addr[31:0]	;
end

//高32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr[63:32]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR_H)
		r_ch0_base_addr[63:32]	<=	pio_wr_data	;
	else
		r_ch0_base_addr[63:32]	<=	r_ch0_base_addr[63:32]	;
end

//低32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr2[31:0]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR1_L)
		r_ch0_base_addr2[31:0]	<=	pio_wr_data	;
	else
		r_ch0_base_addr2[31:0]	<=	r_ch0_base_addr2[31:0]	;
end

//高32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr2[63:32]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR1_H)
		r_ch0_base_addr2[63:32]	<=	pio_wr_data	;
	else
		r_ch0_base_addr2[63:32]	<=	r_ch0_base_addr2[63:32]	;
end

//低32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr3[31:0]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR2_L)
		r_ch0_base_addr3[31:0]	<=	pio_wr_data	;
	else
		r_ch0_base_addr3[31:0]	<=	r_ch0_base_addr3[31:0]	;
end

//高32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr3[63:32]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR2_H)
		r_ch0_base_addr3[63:32]	<=	pio_wr_data	;
	else
		r_ch0_base_addr3[63:32]	<=	r_ch0_base_addr3[63:32]	;
end

//低32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr4[31:0]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR3_L)
		r_ch0_base_addr4[31:0]	<=	pio_wr_data	;
	else
		r_ch0_base_addr4[31:0]	<=	r_ch0_base_addr4[31:0]	;
end

//高32
always@(posedge pcie_clk)	begin
	if(!rst_n)	
		r_ch0_base_addr4[63:32]	<=	'd0	;
	else	if(pio_wr_en && pio_wr_addr == DMA_ADDR3_H)
		r_ch0_base_addr4[63:32]	<=	pio_wr_data	;
	else
		r_ch0_base_addr4[63:32]	<=	r_ch0_base_addr4[63:32]	;
end


//写完一帧信号
always@(posedge pcie_clk)	begin
	if(!rst_n)	
        r_wr_frame_done    <=    1'd0    ;    
    else    if(pio_rd_en && pio_rd_addr == WR_FRAME_DONE)
        r_wr_frame_done    <=    1'd0    ;
    else    if(i_wr_frame_done)
        r_wr_frame_done    <=    1'd1    ;
    else
        r_wr_frame_done    <=    r_wr_frame_done    ;
end



//pio_read
always@(posedge pcie_clk)	begin
	if(!rst_n)
        r_pio_rd_data    <=    32'd0    ;
    else    if(pio_rd_en)    begin
        case(pio_rd_addr)
            WR_FRAME_DONE    :    r_pio_rd_data    <=    {29'd0,i_wr_index,r_wr_frame_done};
            default          :    r_pio_rd_data    <=    32'd0;
        endcase
    end
end

//--------------------------------------------------------------------------------------
//开始
assign start_flag = r_start_flag	;
assign set_dma_config_en = r_set_dma_config_en    ;

assign pio_rd_data 	= r_pio_rd_data;
assign o_ch0_base_addr  = r_ch0_base_addr	;
assign o_ch0_base_addr2 = r_ch0_base_addr2	;
assign o_ch0_base_addr3 = r_ch0_base_addr3	;
assign o_ch0_base_addr4 = r_ch0_base_addr4	;
//-------------预留---------------



endmodule