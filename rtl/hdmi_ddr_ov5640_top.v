`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
// 
// Create Date: 2023-03-17  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
//cmos1、cmos2二选一，作为视频源输入
`define CMOS_1      //cmos1作为视频输入；
//`define CMOS_2      //cmos2作为视频输入；

module hdmi_ddr_ov5640_top#(
	parameter MEM_ROW_ADDR_WIDTH   = 15         ,
	parameter MEM_COL_ADDR_WIDTH   = 10         ,
	parameter MEM_BADDR_WIDTH      = 3          ,
	parameter MEM_DQ_WIDTH         =  32        ,
	parameter MEM_DQS_WIDTH        =  32/8
)(
	input                                sys_clk              ,//27Mhz
    input                                clk_p                ,
    input                                clk_n                ,
    //pcie
    input                                button_rst_n         ,
    input                                perst_n              ,
    //clk and rst                                             
    input                                ref_clk_n            ,      //100 Mhz
    input                                ref_clk_p            ,      //100 Mhz
    //diff signals                                            
                                                              
    input           [1:0]                rxn                  ,
    input           [1:0]                rxp                  ,
    output  wire    [1:0]                txn                  ,
    output  wire    [1:0]                txp                  ,
    //LED signals                                             

    output wire                          smlh_link_up         ,
    output wire                          rdlh_link_up         ,


    //sfp
    input                                sfp_clk_p            ,
    input                                sfp_clk_n            ,

    output                               sfp_tx0_p            ,            
    output                               sfp_tx0_n            ,            
    output                               sfp_tx1_p            ,            
    output                               sfp_tx1_n            ,            

    input                                sfp_rx0_p            ,            
    input                                sfp_rx0_n            ,            
    input                                sfp_rx1_p            ,            
    input                                sfp_rx1_n            , 
    output                               TX_DISABLE2          ,
    output                               TX_DISABLE3          ,


//OV5647
    output  [1:0]                        cmos_init_done       ,//OV5640寄存器初始化完成


//key
    //input  [4:0]                         key                    ,//key
//DDR
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_cs_n                  ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a                     ,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,
    output reg                           heart_beat_led            ,
    output                               ddr_init_done             ,
//MS72xx       
    output                               rstn_out                  ,
    output                               iic_scl,
    inout                                iic_sda, 
    output                               iic_tx_scl                ,
    inout                                iic_tx_sda                ,
    output                               hdmi_int_led              ,//HDMI_OUT初始化完成



//HDMI_IN
    input                                pixclk_in                 /*synthesis PAP_MARK_DEBUG="1"*/,                            
    input                                vs_in                     ,  
    input                                hs_in                     , 
    input                                de_in                     , 
    input     [7:0]                      r_in                      , 
    input     [7:0]                      g_in                      , 
    input     [7:0]                      b_in                      , 
//HDMI_OUT
    output                               pix_clk                   ,//pixclk                           
    output     reg                       vs_out                    , 
    output     reg                       hs_out                    , 
    output     reg                       de_out                    ,
    output     reg[7:0]                  r_out                     , 
    output     reg[7:0]                  g_out                     , 
    output     reg[7:0]                  b_out         
);
//==================================================================================
// TX_DISABLE
//==================================================================================
assign TX_DISABLE2 = 1'b0    ;
assign TX_DISABLE3 = 1'b0    ;
//==================================================================================
// led 相关信号定义
//==================================================================================
reg                           ref_led              ;
reg                           pclk_led             ;
//==================================================================================
// sfp 相关信号定义
//==================================================================================
wire                sfp_tx_clk/* synthesis syn_keep=1 */;
wire                sfp_rx_clk/* synthesis syn_keep=1 */;
wire                o_p_clk2core_rx_2;
wire                o_p_clk2core_tx_3;

wire   [31:0]       sfp_rx_data   ;
wire   [3:0]        sfp_rx_kchar  /* synthesis PAP_MARK_DEBUG="true" */;

wire   [31:0]       sfp_rx_data_align /* synthesis PAP_MARK_DEBUG="true" */;
wire   [3:0]        sfp_rx_kchar_align /* synthesis PAP_MARK_DEBUG="true" */;

reg    [31:0]       sfp_tx_data /* synthesis PAP_MARK_DEBUG="true" */;
reg    [3:0]        sfp_tx_kchar /* synthesis PAP_MARK_DEBUG="true" */;

assign TX_DISABLE2 = 1'b0;
assign TX_DISABLE3 = 1'b0;

assign sfp_tx_clk = o_p_clk2core_tx_3;
assign sfp_rx_clk = o_p_clk2core_rx_2;



always @(posedge sfp_tx_clk)begin
    if (!ddr_init_done)begin
        sfp_tx_data <= 32'hacacacbc;
        sfp_tx_kchar <= 4'b0001;
    end
    else begin
        sfp_tx_data <= 32'hacacacbc;
        sfp_tx_kchar <= 4'b0001;
    end
end

/////////////////////////////////////////////////////////////////////////////////////
// ENABLE_DDR
parameter CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;//28
parameter TH_1S = 27'd33000000;
/////////////////////////////////////////////////////////////////////////////////////
reg  [15:0]                 rstn_1ms            ;
wire                        cmos_scl            ;//cmos i2c clock
wire                        cmos_sda            ;//cmos i2c data
wire                        cmos_vsync          ;//cmos vsync
wire                        cmos_href           ;//cmos hsync refrence,data valid
wire                        cmos_pclk           ;//cmos pxiel clock
wire   [7:0]                cmos_data           ;//cmos data
wire                        cmos_reset          ;//cmos reset
wire                        initial_en          ;
wire[15:0]                  cmos1_d_16bit       ;
wire                        cmos1_href_16bit    ;
reg [7:0]                   cmos1_d_d0          ;
reg                         cmos1_href_d0       ;
reg                         cmos1_vsync_d0      ;
wire                        cmos1_pclk_16bit    ;
wire[15:0]                  cmos2_d_16bit       /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cmos2_href_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
reg [7:0]                   cmos2_d_d0          /*synthesis PAP_MARK_DEBUG="1"*/;
reg                         cmos2_href_d0       /*synthesis PAP_MARK_DEBUG="1"*/;
reg                         cmos2_vsync_d0      /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cmos2_pclk_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
wire[15:0]                  o_rgb565            ;
wire                        pclk_in_test        ;    
wire                        vs_in_test          ;
wire                        de_in_test          ;
wire[15:0]                  i_rgb565            ;
wire                        pclk2_in_test       ;
wire                        vs2_in_test         ;
wire                        de2_in_test         ;
wire[15:0]                  i2_rgb565           ;
wire                        de_re               ;
wire                        vs_o                ;
wire                        lcd_req             ;
wire                        lcd_req_ack         ;

//axi bus   
wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr                 ;
wire                        axi_awuser_ap              ;
wire [3:0]                  axi_awuser_id              ;
wire [7:0]                  axi_awlen                  ;
wire                        axi_awready                ;/*synthesis PAP_MARK_DEBUG="1"*/
wire                        axi_awvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata                  ;
wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb                  ;
wire                        axi_wready                 ;/*synthesis PAP_MARK_DEBUG="1"*/
wire [3:0]                  axi_wusero_id              ;
wire                        axi_wusero_last            ;
wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr                 ;
wire                        axi_aruser_ap              ;
wire [3:0]                  axi_aruser_id              ;
wire [7:0]                  axi_arlen                  ;
wire                        axi_arready                ;/*synthesis PAP_MARK_DEBUG="1"*/
wire                        axi_arvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata                   /* synthesis syn_keep = 1 */;
wire                        axi_rvalid                  /* synthesis syn_keep = 1 */;
wire [3:0]                  axi_rid                    ;
wire                        axi_rlast                  ;
reg  [26:0]                 cnt                        ;
reg  [15:0]                 cnt_1                      ;



	
/************************************************************
AXI参数定定义
************************************************************/	
parameter MEM_DATA_BITS          = 256;             //external memory user interface data width
parameter ADDR_BITS              = 25;             //external memory user interface address width
parameter BUSRT_BITS             = 10;             //external memory user interface burst width
wire                            wr_burst_data_req;
wire                            wr_burst_finish;
wire                            rd_burst_finish;
wire                            rd_burst_req;
wire                            wr_burst_req;
wire[BUSRT_BITS - 1:0]          rd_burst_len;
wire[BUSRT_BITS - 1:0]          wr_burst_len;
wire[ADDR_BITS - 1:0]           rd_burst_addr;
wire[ADDR_BITS - 1:0]           wr_burst_addr;
wire                            rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     wr_burst_data;

wire [3:0]                      s00_axi_awid;
wire [63:0]                     s00_axi_awaddr;
wire [7:0]                      s00_axi_awlen;    // burst length: 0-255
wire [2:0]                      s00_axi_awsize;   // burst size: fixed 2'b011
wire [1:0]                      s00_axi_awburst;  // burst type: fixed 2'b01(incremental burst)
wire                            s00_axi_awlock;   // lock: fixed 2'b00
wire [3:0]                      s00_axi_awcache;  // cache: fiex 2'b0011
wire [2:0]                      s00_axi_awprot;   // protect: fixed 2'b000
wire [3:0]                      s00_axi_awqos;    // qos: fixed 2'b0000
wire [0:0]                      s00_axi_awuser;   // user: fixed 32'd0
wire                            s00_axi_awvalid;
wire                            s00_axi_awready;
// master write data
wire [MEM_DATA_BITS - 1 : 0]    s00_axi_wdata/*synthesis PAP_MARK_DEBUG = "ture"*/;
wire [MEM_DATA_BITS/8 - 1:0]    s00_axi_wstrb;
wire                            s00_axi_wlast;
wire [0:0]                      s00_axi_wuser;
wire                            s00_axi_wvalid;
wire                            s00_axi_wready;
// master write response
wire [3:0]                      s00_axi_bid;
wire [1:0]                      s00_axi_bresp;
wire [0:0]                      s00_axi_buser;
wire                            s00_axi_bvalid;
wire                            s00_axi_bready;
// master read address
wire [3:0]                      s00_axi_arid;
wire [63:0]                     s00_axi_araddr;
wire [7:0]                      s00_axi_arlen;
wire [2:0]                      s00_axi_arsize;
wire [1:0]                      s00_axi_arburst;
wire [1:0]                      s00_axi_arlock;
wire [3:0]                      s00_axi_arcache;
wire [2:0]                      s00_axi_arprot;
wire [3:0]                      s00_axi_arqos;
wire [0:0]                      s00_axi_aruser;
wire                            s00_axi_arvalid;
wire                            s00_axi_arready;
// master read data
wire [3:0]                      s00_axi_rid;
wire [MEM_DATA_BITS - 1 : 0]    s00_axi_rdata/*synthesis PAP_MARK_DEBUG = "ture"*/;
wire [1:0]                      s00_axi_rresp;
wire                            s00_axi_rlast;
wire [0:0]                      s00_axi_ruser;
wire                            s00_axi_rvalid;
wire                            s00_axi_rready;	



/************************************************************
通道一
************************************************************/
wire                            ch0_wr_burst_data_req;
wire                            ch0_wr_burst_finish;
wire                            ch0_rd_burst_finish;
wire                            ch0_rd_burst_req;
wire                            ch0_wr_burst_req;
wire[BUSRT_BITS - 1:0]          ch0_rd_burst_len;
wire[BUSRT_BITS - 1:0]          ch0_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch0_rd_burst_addr;
wire[ADDR_BITS - 1:0]           ch0_wr_burst_addr;
wire                            ch0_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch0_rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     ch0_wr_burst_data;

wire                            ch0_read_req;
wire                            ch0_read_req_ack;
wire                            ch0_read_en;
wire[15:0]                      ch0_read_data;
wire                            ch0_write_en;
wire[15:0]                      ch0_write_data;
wire                            ch0_write_req;
wire                            ch0_write_req_ack;
wire[1:0]                       ch0_write_addr_index;
wire[1:0]                       ch0_read_addr_index;

wire                            read_req;
wire                            read_req_ack;
wire                            read_en/*synthesis PAP_MARK_DEBUG = "ture"*/;
wire[15:0]                      read_data/*synthesis PAP_MARK_DEBUG = "ture"*/;
wire                            write_en/*synthesis PAP_MARK_DEBUG = "ture"*/;
wire[15:0]                      write_data /*synthesis PAP_MARK_DEBUG = "ture"*/;
wire                            write_req;
wire                            write_req_ack;
wire[1:0]                       write_addr_index;
wire[1:0]                       read_addr_index;
/************************************************************
通道二
************************************************************/
wire                            ch1_wr_burst_data_req;
wire                            ch1_wr_burst_finish;
wire                            ch1_rd_burst_finish;
wire                            ch1_rd_burst_req;
wire                            ch1_wr_burst_req;
wire[BUSRT_BITS - 1:0]          ch1_rd_burst_len;
wire[BUSRT_BITS - 1:0]          ch1_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch1_rd_burst_addr;
wire[ADDR_BITS - 1:0]           ch1_wr_burst_addr;
wire                            ch1_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch1_rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     ch1_wr_burst_data;
wire                            ch1_read_req;
wire                            ch1_read_req_ack;
wire                            ch1_read_en;
wire[15:0]                      ch1_read_data;
wire                            ch1_write_en;
wire[15:0]                      ch1_write_data;
wire                            ch1_write_req;
wire                            ch1_write_req_ack;
wire[1:0]                       ch1_write_addr_index;
wire[1:0]                       ch1_read_addr_index;
/************************************************************
通道三
************************************************************/
wire                            ch2_wr_burst_data_req;
wire                            ch2_wr_burst_finish;
wire                            ch2_rd_burst_finish;
wire                            ch2_rd_burst_req;
wire                            ch2_wr_burst_req;
wire[BUSRT_BITS - 1:0]          ch2_rd_burst_len;
wire[BUSRT_BITS - 1:0]          ch2_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch2_rd_burst_addr;
wire[ADDR_BITS - 1:0]           ch2_wr_burst_addr;
wire                            ch2_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch2_rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     ch2_wr_burst_data;
wire                            ch2_read_req;
wire                            ch2_read_req_ack;
wire                            ch2_read_en;
wire[15:0]                      ch2_read_data;
wire                            ch2_write_en;
wire[15:0]                      ch2_write_data;
wire                            ch2_write_req;
wire                            ch2_write_req_ack;
wire[1:0]                       ch2_write_addr_index;
wire[1:0]                       ch2_read_addr_index;
/************************************************************
通道四
************************************************************/
wire                            ch3_wr_burst_data_req;
wire                            ch3_wr_burst_finish;
wire                            ch3_rd_burst_finish;
wire                            ch3_rd_burst_req;
wire                            ch3_wr_burst_req;
wire[BUSRT_BITS - 1:0]          ch3_rd_burst_len;
wire[BUSRT_BITS - 1:0]          ch3_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch3_rd_burst_addr;
wire[ADDR_BITS - 1:0]           ch3_wr_burst_addr;
wire                            ch3_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch3_rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     ch3_wr_burst_data;
wire                            ch3_read_req;
wire                            ch3_read_req_ack;
wire                            ch3_read_en;
wire[15:0]                      ch3_read_data;
wire                            ch3_write_en;
wire[15:0]                      ch3_write_data;
wire                            ch3_write_req;
wire                            ch3_write_req_ack;
wire[1:0]                       ch3_write_addr_index;
wire[1:0]                       ch3_read_addr_index;    
/////////////////////////////////////////////////////////////////////////////////////
//PLL
pll u_pll (
    .clkin1   (  sys_clk    ),//50MHz
    .clkout0  (  pix_clk    ),// 148.5M   1080p
    .clkout1  (  cfg_clk    ),//10MHz
    // .clkout2  (  clk_25M    ),//25M
    .lock     (  locked     )
);


ms72xx_ctl ms72xx_ctl(
    .clk         (  cfg_clk    ), //input       clk,
    .rst_n       (  rstn_out   ), //input       rstn,
           
    .init_over_rx(  ),                 
    .init_over   (  init_over  ), //output      init_over,
    .iic_scl     (  iic_tx_scl    ), //output      iic_scl,
    .iic_sda     (  iic_tx_sda    )  //inout       iic_sda
);



   assign    hdmi_int_led    =    init_over; 
    
    always @(posedge cfg_clk)
    begin
    	if(!locked)
    	    rstn_1ms <= 16'd0;
    	else
    	begin
    		if(rstn_1ms == 16'h2710)
    		    rstn_1ms <= rstn_1ms;
    		else
    		    rstn_1ms <= rstn_1ms + 1'b1;
    	end
    end
    
    assign rstn_out = (rstn_1ms == 16'h2710);

//==================================================================================
//sfp接收图像数据
//==================================================================================
wire              txlane_done_2    ;
wire              txlane_done_3    ;
wire              rxlane_done_2    ;
wire              rxlane_done_3    ;
wire              tx0_clk          ;
wire              tx1_clk          ;
wire              rx0_clk          ;
wire              rx1_clk          ;
wire    [31:0]    rx0_data         ;
wire    [31:0]    rx1_data         ;
wire    [3:0]     rx0_kchar        ;
wire    [3:0]     rx1_kchar        ;
wire    [31:0]    tx0_data         ;
wire    [31:0]    tx1_data         ;
wire    [3:0]     tx0_kchar        ;
wire    [3:0]     tx1_kchar        ;

sfp_hsst sfp_hsst_inst (
  .i_free_clk             (sys_clk             ),        // input
  .i_pll_rst_0            (~button_rst_n       ),        // input
  .i_wtchdg_clr_0         (~button_rst_n       ),        // input
                                               
  .o_txlane_done_2        (txlane_done_2       ),        // output
  .o_txlane_done_3        (txlane_done_3       ),        // output
  .o_rxlane_done_2        (rxlane_done_2       ),        // output
  .o_rxlane_done_3        (rxlane_done_3       ),        // output
  .i_p_refckn_0           (sfp_clk_n           ),        // input
  .i_p_refckp_0           (sfp_clk_p           ),        // input
  .o_p_clk2core_tx_2      (tx0_clk             ),        // output
  .o_p_clk2core_tx_3      (tx1_clk             ),
  .i_p_tx2_clk_fr_core    (tx0_clk             ),        // input
  .i_p_tx3_clk_fr_core    (tx1_clk             ),        // input
  .o_p_clk2core_rx_2      (rx0_clk             ),        // output
  .o_p_clk2core_rx_3      (rx1_clk             ),
  .i_p_rx2_clk_fr_core    (rx0_clk             ),        // input
  .i_p_rx3_clk_fr_core    (rx1_clk             ),        // input
  .i_p_pcs_word_align_en_2(1'b1                ),       // input
  .i_p_pcs_word_align_en_3(1'b1                ),       // input
  .i_p_l2rxn              (sfp_rx0_n           ),       // input
  .i_p_l2rxp              (sfp_rx0_p           ),       // input
  .i_p_l3rxn              (sfp_rx1_n           ),       // input
  .i_p_l3rxp              (sfp_rx1_p           ),       // input
  .o_p_l2txn              (sfp_tx0_n           ),       // output
  .o_p_l2txp              (sfp_tx0_p           ),       // output
  .o_p_l3txn              (sfp_tx1_n           ),       // output
  .o_p_l3txp              (sfp_tx1_p           ),       // output
  .i_txd_2                (i_txd_2             ),       // input [31:0]
  .i_tdispsel_2           (i_tdispsel_2        ),       // input [3:0]
  .i_tdispctrl_2          (i_tdispctrl_2       ),       // input [3:0]
  .i_txk_2                (i_txk_2             ),       // input [3:0]

  .i_txd_3                (i_txd_3             ),       // input [31:0]
  .i_tdispsel_3           (i_tdispsel_3        ),       // input [3:0]
  .i_tdispctrl_3          (i_tdispctrl_3       ),       // input [3:0]
  .i_txk_3                (i_txk_3             ),       // input [3:0]

  .o_rxd_2                (rx0_data            ),       // output [31:0]
  .o_rxk_2                (rx0_kchar           ),       // output [3:0]

  .o_rxd_3                (rx1_data            ),       // output [31:0]
  .o_rxk_3                (rx1_kchar           )        // output [3:0]
);

//==================================================================================
//字节对齐
//==================================================================================
wire    [31:0] rx0_data_align ;
wire    [3:0]  rx0_kchar_align;
wire    [31:0] rx1_data_align ;
wire    [3:0]  rx1_kchar_align;
word_align u_word_align_0(
    .rst           ( 1'b0            ),
    .rx_clk        ( rx0_clk         ),
    .gt_rx_data    ( rx0_data        ),
    .gt_rx_ctrl    ( rx0_kchar       ),
    .rx_data_align ( rx0_data_align  ),
    .rx_ctrl_align ( rx0_kchar_align )
);

word_align u_word_align_1(
    .rst           ( 1'b0            ),
    .rx_clk        ( rx1_clk         ),
    .gt_rx_data    ( rx1_data        ),
    .gt_rx_ctrl    ( rx1_kchar       ),
    .rx_data_align ( rx1_data_align  ),
    .rx_ctrl_align ( rx1_kchar_align )
);
//==================================================================================
//恢复数据
//==================================================================================
wire            sfp0_rx_vs   ;
wire            sfp0_rx_de   ;
wire    [15:0]  sfp0_rx_data ;
wire            sfp1_rx_vs   ;
wire            sfp1_rx_de   ;
wire    [15:0]  sfp1_rx_data ;
video_packet_rec u_video_packet_rec_0
(
    .rst        ( 1'b0            ),
    .rx_clk     ( rx0_clk         ),
    .gt_rx_data ( rx0_data_align  ),
    .gt_rx_ctrl ( rx0_kchar_align ),
    .vout_width ( 960             ),
    .vs         ( sfp0_rx_vs      ),
    .de         ( sfp0_rx_de      ),
    .vout_data  ( sfp0_rx_data    )
);

video_packet_rec u_video_packet_rec_1
(
    .rst        ( 1'b0            ),
    .rx_clk     ( rx1_clk         ),
    .gt_rx_data ( rx1_data_align  ),
    .gt_rx_ctrl ( rx1_kchar_align ),
    .vout_width ( 960             ),
    .vs         ( sfp1_rx_vs      ),
    .de         ( sfp1_rx_de      ),
    .vout_data  ( sfp1_rx_data    )
);


//==================================================================================
//ddr写数据
//==================================================================================
wire                              core_clk;
wire                              ch0_rframe_req;
wire                              ch0_rframe_req_ack;
wire                              ch0_rframe_data_en;
wire  [15:0]                      ch0_rframe_data;
wire                              ch0_rframe_data_valid;
                                  
wire                              ch1_rframe_req;
wire                              ch1_rframe_req_ack;
wire                              ch1_rframe_data_en;
wire  [15:0]                      ch1_rframe_data;
wire                              ch1_rframe_data_valid;
                                  
wire                              ch2_rframe_req;
wire                              ch2_rframe_req_ack;
wire                              ch2_rframe_data_en;
wire  [15:0]                      ch2_rframe_data;
wire                              ch2_rframe_data_valid;
                                  
wire                              ch3_rframe_req;
wire                              ch3_rframe_req_ack;
wire                              ch3_rframe_data_en;
wire  [15:0]                      ch3_rframe_data;
wire                              ch3_rframe_data_valid;
wire  [3:0]                       axi_awid;
wire  [2:0]                       axi_awsize ;
wire  [1:0]                       axi_awburst                  ;        //only support 2'b01: INCR
wire                              axi_wlast                    ;
wire                              axi_wvalid                   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                              axi_bready                   ;
wire [2:0]                        axi_arsize                   ;
wire [1:0]                        axi_arburst                  ;       //only support 2'b01: INCR
wire                              axi_rready                   ;



reg  [15:0]    ch0_hdmi_data_in    /*synthesis PAP_MARK_DEBUG="1"*/;
reg            ch0_hdmi_vs_in      /*synthesis PAP_MARK_DEBUG="1"*/;
reg            ch0_hdmi_de_in      /*synthesis PAP_MARK_DEBUG="1"*/;
always@(posedge pixclk_in)    begin
    ch0_hdmi_data_in    <=    {r_in[7:3],g_in[7:2],b_in[7:3]};
    ch0_hdmi_vs_in      <=    vs_in    ;
    ch0_hdmi_de_in      <=    de_in    ;        
end
/************************************************************
1920x1080->960x540
************************************************************/
wire              hdmi_1_scale_de;
wire    [15:0]    hdmi_1_scale_data;
video_scale_process#(
    .PIX_DATA_WIDTH       ( 16 )
)u_video_scale_process_0(
    .video_clk            ( pixclk_in          ),
    .rst_n                ( rstn_out             ),
    .frame_sync_n         ( ~ch0_hdmi_vs_in       ),
    .video_data_in        ( ch0_hdmi_data_in     ),
    .video_data_valid     ( ch0_hdmi_de_in     ),
    .video_data_out       ( hdmi_1_scale_data       ),
    .video_data_out_valid ( hdmi_1_scale_de ),
    .video_ready          ( 1'b1          ),
    .video_width_in       ( 1920       ),
    .video_height_in      ( 1080      ),
    .video_width_out      ( 960      ),
    .video_height_out     ( 540     )
);


/************************************************************
帧开始 就开始切换地址
************************************************************/
//CMOS sensor writes the request and generates the read and write address index
//通道一
cmos_write_req_gen cmos_write_req_gen_m0(
	.rst                        (~rstn_out                ),
	.pclk                       (pixclk_in                ),
	.cmos_vsync                 (ch0_hdmi_vs_in           ),
	.write_req                  (ch0_write_req            ),
	.write_addr_index           (ch0_write_addr_index     ),
	.read_addr_index            (ch0_read_addr_index      ),
	.write_req_ack              (ch0_write_req_ack        )
);

//通道二 hdmi
cmos_write_req_gen cmos_write_req_gen_m1(
	.rst                        (~rstn_out                ),
	.pclk                       (pixclk_in                ),
	.cmos_vsync                 (ch0_hdmi_vs_in           ),
	.write_req                  (ch1_write_req            ),
	.write_addr_index           (ch1_write_addr_index     ),
	.read_addr_index            (ch1_read_addr_index      ),
	.write_req_ack              (ch1_write_req_ack        )
);


//通道三 hdmi
cmos_write_req_gen cmos_write_req_gen_m2(
	.rst                        (~rstn_out                ),
	.pclk                       (rx0_clk                  ),
	.cmos_vsync                 (sfp0_rx_vs               ),
	.write_req                  (ch2_write_req            ),
	.write_addr_index           (ch2_write_addr_index     ),
	.read_addr_index            (ch2_read_addr_index      ),
	.write_req_ack              (ch2_write_req_ack        )
);

//通道三 hdmi
cmos_write_req_gen cmos_write_req_gen_m3(
	.rst                        (~rstn_out                ),
	.pclk                       (rx1_clk                  ),
	.cmos_vsync                 (sfp1_rx_vs               ),
	.write_req                  (ch3_write_req            ),
	.write_addr_index           (ch3_write_addr_index     ),
	.read_addr_index            (ch3_read_addr_index      ),
	.write_req_ack              (ch3_write_req_ack        )
);
/************************************************************
ddr读写控制
************************************************************/
wire    ch0_clk;
wire    ch1_clk;
wire    ch2_clk;
wire    ch3_clk;


//通道一 
assign ch0_write_data = hdmi_1_scale_data;
assign ch0_write_en   = hdmi_1_scale_de;
assign ch0_clk        = pixclk_in;

//通道二 hdmi输入
assign ch1_write_data = hdmi_1_scale_data;
assign ch1_write_en   = hdmi_1_scale_de;
assign ch1_clk        = pixclk_in;



//通道三 hdmi输入
assign ch2_write_data = sfp0_rx_data;
assign ch2_write_en   = sfp0_rx_de;
assign ch2_clk        = rx0_clk;


//通道四 hdmi输入
assign ch3_write_data = sfp1_rx_data;
assign ch3_write_en   = sfp1_rx_de;
assign ch3_clk        = rx1_clk;


frame_read_write
#
(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                      ) //?
)
frame_read_write_m0
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch0_rd_burst_req             ),
	.rd_burst_len               (ch0_rd_burst_len             ),
	.rd_burst_addr              (ch0_rd_burst_addr            ),
	.rd_burst_data_valid        (ch0_rd_burst_data_valid      ),
	.rd_burst_data              (ch0_rd_burst_data            ),
	.rd_burst_finish            (ch0_rd_burst_finish          ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch0_read_req            ),
	.read_req_ack               (ch0_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd0                    ), //The first frame address is 0
	.read_addr_1                (25'd2073600              ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd4147200              ),
	.read_addr_3                (25'd6220800              ),
	.read_addr_index            (ch0_read_addr_index      ),
	.read_len                   (25'd129600                ),//frame size 
	.read_en                    (ch0_read_en              ),
	.read_data                  (ch0_read_data            ),

	.wr_burst_req               (ch0_wr_burst_req             ),
	.wr_burst_len               (ch0_wr_burst_len             ),
	.wr_burst_addr              (ch0_wr_burst_addr            ),
	.wr_burst_data_req          (ch0_wr_burst_data_req        ),
	.wr_burst_data              (ch0_wr_burst_data            ),
	.wr_burst_finish            (ch0_wr_burst_finish          ),
	.write_clk                  (ch0_clk                     ),
	.write_req                  (ch0_write_req            ),
	.write_req_ack              (ch0_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd0                    ),
	.write_addr_1               (25'd2073600              ),
	.write_addr_2               (25'd4147200              ),
	.write_addr_3               (25'd6220800              ),
	.write_addr_index           (ch0_write_addr_index     ),
	.write_len                  (25'd129600                ), //frame size  
	.write_en                   (ch0_write_en             ),
	.write_data                 (ch0_write_data           )
);

frame_read_write
#
(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                      ) //?
)
frame_read_write_m1
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch1_rd_burst_req             ),
	.rd_burst_len               (ch1_rd_burst_len             ),
	.rd_burst_addr              (ch1_rd_burst_addr            ),
	.rd_burst_data_valid        (ch1_rd_burst_data_valid      ),
	.rd_burst_data              (ch1_rd_burst_data            ),
	.rd_burst_finish            (ch1_rd_burst_finish          ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch1_read_req            ),
	.read_req_ack               (ch1_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd8294400               ), //The first frame address is 0
	.read_addr_1                (25'd10368000              ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd12441600              ),
	.read_addr_3                (25'd14515200              ),
	.read_addr_index            (ch1_read_addr_index      ),
	.read_len                   (25'd129600                ),//frame size 
	.read_en                    (ch1_read_en              ),
	.read_data                  (ch1_read_data            ),

	.wr_burst_req               (ch1_wr_burst_req             ),
	.wr_burst_len               (ch1_wr_burst_len             ),
	.wr_burst_addr              (ch1_wr_burst_addr            ),
	.wr_burst_data_req          (ch1_wr_burst_data_req        ),
	.wr_burst_data              (ch1_wr_burst_data            ),
	.wr_burst_finish            (ch1_wr_burst_finish          ),
	.write_clk                  (ch1_clk                     ),
	.write_req                  (ch1_write_req            ),
	.write_req_ack              (ch1_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd8294400               ),
	.write_addr_1               (25'd10368000              ),
	.write_addr_2               (25'd12441600              ),
	.write_addr_3               (25'd14515200              ),
	.write_addr_index           (ch1_write_addr_index     ),
	.write_len                  (25'd129600                ), //frame size  
	.write_en                   (ch1_write_en             ),
	.write_data                 (ch1_write_data           )
);

//通道三
frame_read_write#(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                       ) //?
) frame_read_write_m2
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch2_rd_burst_req         ),
	.rd_burst_len               (ch2_rd_burst_len         ),
	.rd_burst_addr              (ch2_rd_burst_addr        ),
	.rd_burst_data_valid        (ch2_rd_burst_data_valid  ),
	.rd_burst_data              (ch2_rd_burst_data        ),
	.rd_burst_finish            (ch2_rd_burst_finish      ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch2_read_req             ),
	.read_req_ack               (ch2_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd16588800             ), //The first frame address is 0
	.read_addr_1                (25'd18662400             ), //The second frame address is 25'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd20736000             ),
	.read_addr_3                (25'd22809600             ),
	.read_addr_index            (ch2_read_addr_index      ),
	.read_len                   (25'd129600               ),//frame size  1024 * 768 * 16 / 64
	.read_en                    (ch2_read_en              ),
	.read_data                  (ch2_read_data            ),

	.wr_burst_req               (ch2_wr_burst_req         ),
	.wr_burst_len               (ch2_wr_burst_len         ),
	.wr_burst_addr              (ch2_wr_burst_addr        ),
	.wr_burst_data_req          (ch2_wr_burst_data_req    ),
	.wr_burst_data              (ch2_wr_burst_data        ),
	.wr_burst_finish            (ch2_wr_burst_finish      ),
	.write_clk                  (ch2_clk                ),
	.write_req                  (ch2_write_req            ),
	.write_req_ack              (ch2_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd16588800             ),
	.write_addr_1               (25'd18662400             ),
	.write_addr_2               (25'd20736000             ),
	.write_addr_3               (25'd22809600             ),
	.write_addr_index           (ch2_write_addr_index     ),
	.write_len                  (25'd129600                ),
	.write_en                   (ch2_write_en             ),
	.write_data                 (ch2_write_data           )
);
//通道四
frame_read_write#(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                       ) //?
) frame_read_write_m3
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch3_rd_burst_req         ),
	.rd_burst_len               (ch3_rd_burst_len         ),
	.rd_burst_addr              (ch3_rd_burst_addr        ),
	.rd_burst_data_valid        (ch3_rd_burst_data_valid  ),
	.rd_burst_data              (ch3_rd_burst_data        ),
	.rd_burst_finish            (ch3_rd_burst_finish      ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch3_read_req             ),
	.read_req_ack               (ch3_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd24883200             ), //The first frame address is 0
	.read_addr_1                (25'd26956800             ), //The second frame address is 25'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd29030400             ),
	.read_addr_3                (25'd31104000             ),
	.read_addr_index            (ch3_read_addr_index      ),
	.read_len                   (25'd129600               ),//frame size  1024 * 768 * 16 / 64
	.read_en                    (ch3_read_en              ),
	.read_data                  (ch3_read_data            ),

	.wr_burst_req               (ch3_wr_burst_req         ),
	.wr_burst_len               (ch3_wr_burst_len         ),
	.wr_burst_addr              (ch3_wr_burst_addr        ),
	.wr_burst_data_req          (ch3_wr_burst_data_req    ),
	.wr_burst_data              (ch3_wr_burst_data        ),
	.wr_burst_finish            (ch3_wr_burst_finish      ),
	.write_clk                  (ch3_clk                ),
	.write_req                  (ch3_write_req            ),
	.write_req_ack              (ch3_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd24883200             ),
	.write_addr_1               (25'd26956800             ),
	.write_addr_2               (25'd29030400             ),
	.write_addr_3               (25'd31104000             ),
	.write_addr_index           (ch3_write_addr_index     ),
	.write_len                  (25'd129600                ),
	.write_en                   (ch3_write_en             ),
	.write_data                 (ch3_write_data           )
);

//产生色彩叠加
wire [7:0]    color_bar_r;
wire [7:0]    color_bar_g;
wire [7:0]    color_bar_b;
wire [15:0]   v0_data     ;
wire          v0_hs        ;
wire          v0_vs        ;
wire          v0_de        ;
color_bar color_bar_m0(
	.clk                        (pix_clk                ),
	.rst                        (~rstn_out               ),
	.hs                         (color_bar_hs             ),
	.vs                         (color_bar_vs             ),
	.de                         (color_bar_de             ),
	.rgb_r                      (color_bar_r              ),
	.rgb_g                      (color_bar_g              ),
	.rgb_b                      (color_bar_b              )
);
//读写偏移请求
//generate a frame read data request
video_rect_read_data video_rect_read_data_m0
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out               ),
	.video_left_offset          (12'd0                    ),
	.video_top_offset           (12'd0                    ),
	.video_width                (12'd960                 ),
	.video_height	            (12'd540                  ),
	.read_req                   (ch0_read_req             ),
	.read_req_ack               (ch0_read_req_ack         ),
	.read_en                    (ch0_read_en              ),
	.read_data                  (ch0_read_data            ),
	.timing_hs                  (color_bar_hs             ),
	.timing_vs                  (color_bar_vs             ),
	.timing_de                  (color_bar_de             ),
	.timing_data 	            (),
	.hs                         (v0_hs                    ),
	.vs                         (v0_vs                    ),
	.de                         (v0_de                    ),
	.vout_data                  (v0_data                  )
);
//通道二
wire    [15:0]    v1_data;
wire    v1_hs;
wire    v1_vs;
wire    v1_de;

video_rect_read_data video_rect_read_data_m1
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out               ),
	.video_left_offset          (12'd960                  ),
	.video_top_offset           (12'd0                    ),
	.video_width                (12'd960                  ),
	.video_height	            (12'd540                  ),
	.read_req                   (ch1_read_req             ),
	.read_req_ack               (ch1_read_req_ack         ),
	.read_en                    (ch1_read_en              ),
	.read_data                  (ch1_read_data            ),
	.timing_hs                  (v0_hs                    ),
	.timing_vs                  (v0_vs                    ),
	.timing_de                  (v0_de                    ),
	.timing_data 	            (v0_data                  ),
	.hs                         (v1_hs                       ),
	.vs                         (v1_vs                       ),
	.de                         (v1_de                       ),
	.vout_data                  (v1_data                )
);
//通道三
wire    [15:0]    v2_data;
wire    v2_hs;
wire    v2_vs;
wire    v2_de;

video_rect_read_data video_rect_read_data_m2
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out               ),
	.video_left_offset          (12'd0                  ),
	.video_top_offset           (12'd540                    ),
	.video_width                (12'd960                  ),
	.video_height	            (12'd540                  ),
	.read_req                   (ch2_read_req             ),
	.read_req_ack               (ch2_read_req_ack         ),
	.read_en                    (ch2_read_en              ),
	.read_data                  (ch2_read_data            ),
	.timing_hs                  (v1_hs                    ),
	.timing_vs                  (v1_vs                    ),
	.timing_de                  (v1_de                    ),
	.timing_data 	            (v1_data                  ),
	.hs                         (v2_hs                       ),
	.vs                         (v2_vs                       ),
	.de                         (v2_de                       ),
	.vout_data                  (v2_data                )
);
//通道四
wire    [15:0]    v3_data;
wire    v3_hs;
wire    v3_vs;
wire    v3_de;

video_rect_read_data video_rect_read_data_m3
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out               ),
	.video_left_offset          (12'd960                 ),
	.video_top_offset           (12'd540                    ),
	.video_width                (12'd960                  ),
	.video_height	            (12'd540                  ),
	.read_req                   (ch3_read_req             ),
	.read_req_ack               (ch3_read_req_ack         ),
	.read_en                    (ch3_read_en              ),
	.read_data                  (ch3_read_data            ),
	.timing_hs                  (v2_hs                    ),
	.timing_vs                  (v2_vs                    ),
	.timing_de                  (v2_de                    ),
	.timing_data 	            (v2_data                  ),
	.hs                         (v3_hs                       ),
	.vs                         (v3_vs                       ),
	.de                         (v3_de                       ),
	.vout_data                  (v3_data                )
);



wire              o_vout_vs     ;
wire              o_vout_hs     ;
wire              o_vout_de     ;
wire    [31:0]    o_vout_data   ;


always@(posedge pix_clk) begin

    r_out<={v3_data[15:11],3'b0   };
    g_out<={v3_data[10:5],2'b0    };
    b_out<={v3_data[4:0],3'b0     }; 
    vs_out<=v3_vs;
    hs_out<=v3_hs;
    de_out<=v3_de;
end

wire clk_125Mhz ;

GTP_INBUFGDS #(
    .IOSTANDARD("DEFAULT"),
    .TERM_DIFF("ON")
) u_gtp (
    .O(clk_125Mhz), // OUTPUT  
    .I(clk_p), // INPUT  
    .IB(clk_n) // INPUT  
);
ddr3_100k u_ddr3_100k (
        .ref_clk                   (clk_125Mhz         ),
        .resetn                    (rstn_out           ),// input
        .ddr_init_done             (ddr_init_done      ),// output
        .core_clk                  (core_clk           ),// output
        .pll_lock                  (pll_lock           ),// output
        .phy_pll_lock              (phy_pll_lock),                          // output
        .gpll_lock                 (gpll_lock),                                // output
        .rst_gpll_lock             (rst_gpll_lock),                        // output
        .ddrphy_cpd_lock           (ddrphy_cpd_lock),                    // output

        .axi_awaddr                 (s00_axi_awaddr                   ),
        .axi_awid                   (s00_axi_awid                     ),
        .axi_awlen                  (s00_axi_awlen                    ),
        .axi_awsize                 (s00_axi_awsize                   ),
        .axi_awburst                (s00_axi_awburst                  ),        //only support 2'b01: INCR
        .axi_awready                (s00_axi_awready                  ),
        .axi_awvalid                (s00_axi_awvalid                  ),
        .axi_wdata                  (s00_axi_wdata                    ),
        .axi_wstrb                  (s00_axi_wstrb                    ),
        .axi_wlast                  (s00_axi_wlast                    ),
        .axi_wvalid                 (s00_axi_wvalid                   ),
        .axi_wready                 (s00_axi_wready                   ),
        .axi_bready                 (s00_axi_bready                   ),
        .axi_bid                    (                                 ),
        .axi_bresp                  (                                 ),
        .axi_bvalid                 (                   ),
        //.axi_wusero_id             (                   ),// output [3:0]
        //.axi_wusero_last           (axi_wusero_last    ),// output
        //.axi_aruser_ap             (1'b0               ),// input
        //.axi_aruser_id             (axi_aruser_id      ),// input [3:0]
        .axi_araddr                 (s00_axi_araddr                   ),
        .axi_arid                   (s00_axi_aruser_id                ),
        .axi_arlen                  (s00_axi_arlen                    ),
        .axi_arsize                 (s00_axi_arsize                   ),
        .axi_arburst                (s00_axi_arburst                  ),       //only support 2'b01: INCR
        .axi_arvalid                (s00_axi_arvalid                  ),
        .axi_arready                (s00_axi_arready                  ),
        .axi_rready                 (s00_axi_rready                   ),
        .axi_rdata                  (s00_axi_rdata                    ),
        .axi_rvalid                 (s00_axi_rvalid                   ),
        .axi_rlast                  (s00_axi_rlast                    ),
        .axi_rid                    (s00_axi_rid                      ),
        .axi_rresp                  (                             ),

        .apb_clk                   (1'b0               ),// input
        .apb_rst_n                 (1'b1               ),// input
        .apb_sel                   (1'b0               ),// input
        .apb_enable                (1'b0               ),// input
        .apb_addr                  (8'b0               ),// input [7:0]
        .apb_write                 (1'b0               ),// input
        .apb_ready                 (                   ), // output
        .apb_wdata                 (16'b0              ),// input [15:0]
        .apb_rdata                 (                   ),// output [15:0]
    //  .apb_int                   (                   ),// output

        .mem_rst_n                 (mem_rst_n          ),// output
        .mem_ck                    (mem_ck             ),// output
        .mem_ck_n                  (mem_ck_n           ),// output
        .mem_cke                   (mem_cke            ),// output
        .mem_cs_n                  (mem_cs_n           ),// output
        .mem_ras_n                 (mem_ras_n          ),// output
        .mem_cas_n                 (mem_cas_n          ),// output
        .mem_we_n                  (mem_we_n           ),// output
        .mem_odt                   (mem_odt            ),// output
        .mem_a                     (mem_a              ),// output [14:0]
        .mem_ba                    (mem_ba             ),// output [2:0]
        .mem_dqs                   (mem_dqs            ),// inout [3:0]
        .mem_dqs_n                 (mem_dqs_n          ),// inout [3:0]
        .mem_dq                    (mem_dq             ),// inout [31:0]
        .mem_dm                    (mem_dm             ),// output [3:0]
             //debug
  .dbg_gate_start(1'b0),                      // input
  .dbg_cpd_start(1'b0),                        // input
  .dbg_ddrphy_rst_n(1'b1),                  // input
  .dbg_gpll_scan_rst(1'b0),                // input
  .samp_position_dyn_adj(1'b0),        // input
  .init_samp_position_even(32'd0),    // input [31:0]
  .init_samp_position_odd(32'd0),      // input [31:0]
  .wrcal_position_dyn_adj(1'b0),      // input
  .init_wrcal_position(32'd0),            // input [31:0]
  .force_read_clk_ctrl(1'b0),            // input
  .init_slip_step(16'd0),                      // input [15:0]
  .init_read_clk_ctrl(12'd0),              // input [11:0]
  .debug_calib_ctrl(),                  // output [33:0]
  .dbg_slice_status(),                  // output [67:0]
  .dbg_slice_state(),                    // output [87:0]
  .debug_data(),                              // output [275:0]
  .dbg_dll_upd_state(),                // output [1:0]
  .debug_gpll_dps_phase(),          // output [8:0]
  .dbg_rst_dps_state(),                // output [2:0]
  .dbg_tran_err_rst_cnt(),          // output [5:0]
  .dbg_ddrphy_init_fail(),          // output
  .debug_cpd_offset_adj(1'b0),          // input
  .debug_cpd_offset_dir(1'b0),          // input
  .debug_cpd_offset(10'd0),                  // input [9:0]
  .debug_dps_cnt_dir0(),              // output [9:0]
  .debug_dps_cnt_dir1(),              // output [9:0]
  .ck_dly_en(1'b0),                                // input
  .init_ck_dly_step(8'h0),                  // input [7:0]
  .ck_dly_set_bin(),                      // output [7:0]
  .align_error(),                            // output
  .debug_rst_state(),                    // output [3:0]
  .debug_cpd_state()                     // output [3:0]
       );

/************************************************************
AXI主机
************************************************************/ 
assign s00_axi_bvalid =1'b1; 
aq_axi_master_256	u_aq_axi_master
(
	  .ARESETN                     (ddr_init_done                             ),
	  .ACLK                        (core_clk                                  ),
	  .M_AXI_AWID                  (s00_axi_awid                              ),
	  .M_AXI_AWADDR                (s00_axi_awaddr                            ),
	  .M_AXI_AWLEN                 (s00_axi_awlen                             ),
	  .M_AXI_AWSIZE                (s00_axi_awsize                            ),
	  .M_AXI_AWBURST               (s00_axi_awburst                           ),
	  .M_AXI_AWLOCK                (s00_axi_awlock                            ),
	  .M_AXI_AWCACHE               (s00_axi_awcache                           ),
	  .M_AXI_AWPROT                (s00_axi_awprot                            ),
	  .M_AXI_AWQOS                 (s00_axi_awqos                             ),
	  .M_AXI_AWUSER                (s00_axi_awuser                            ),
	  .M_AXI_AWVALID               (s00_axi_awvalid                           ),
	  .M_AXI_AWREADY               (s00_axi_awready                           ),
	  .M_AXI_WDATA                 (s00_axi_wdata                             ),
	  .M_AXI_WSTRB                 (s00_axi_wstrb                             ),
	  .M_AXI_WLAST                 (s00_axi_wlast                             ),
	  .M_AXI_WUSER                 (s00_axi_wuser                             ),
	  .M_AXI_WVALID                (s00_axi_wvalid                            ),
	  .M_AXI_WREADY                (s00_axi_wready                            ),
	  .M_AXI_BID                   (s00_axi_bid                               ),
	  .M_AXI_BRESP                 (s00_axi_bresp                             ),
	  .M_AXI_BUSER                 (s00_axi_buser                             ),
      .M_AXI_BVALID                (s00_axi_bvalid                            ),

	  .M_AXI_BREADY                (s00_axi_bready                            ),
	  .M_AXI_ARID                  (s00_axi_arid                              ),
	  .M_AXI_ARADDR                (s00_axi_araddr                            ),
	  .M_AXI_ARLEN                 (s00_axi_arlen                             ),
	  .M_AXI_ARSIZE                (s00_axi_arsize                            ),
	  .M_AXI_ARBURST               (s00_axi_arburst                           ),
	  .M_AXI_ARLOCK                (s00_axi_arlock                            ),
	  .M_AXI_ARCACHE               (s00_axi_arcache                           ),
	  .M_AXI_ARPROT                (s00_axi_arprot                            ),
	  .M_AXI_ARQOS                 (s00_axi_arqos                             ),
	  .M_AXI_ARUSER                (s00_axi_aruser                            ),
	  .M_AXI_ARVALID               (s00_axi_arvalid                           ),
	  .M_AXI_ARREADY               (s00_axi_arready                           ),
	  .M_AXI_RID                   (s00_axi_rid                               ),
	  .M_AXI_RDATA                 (s00_axi_rdata                             ),
	  .M_AXI_RRESP                 (s00_axi_rresp                             ),
	  .M_AXI_RLAST                 (s00_axi_rlast                             ),
	  .M_AXI_RUSER                 (s00_axi_ruser                             ),
	  .M_AXI_RVALID                (s00_axi_rvalid                            ),
	  .M_AXI_RREADY                (s00_axi_rready                            ),
	  .MASTER_RST                  (1'b0                                      ),
	  .WR_START                    (wr_burst_req                              ),
	  .WR_ADRS                     ({wr_burst_addr,5'd0}                      ),
	  .WR_LEN                      ({wr_burst_len, 5'd0}                      ),
	  .WR_READY                    (                                          ),
	  .WR_FIFO_RE                  (wr_burst_data_req                         ),
	  .WR_FIFO_EMPTY               (1'b0                                      ),
	  .WR_FIFO_AEMPTY              (1'b0                                      ),
	  .WR_FIFO_DATA                (wr_burst_data                             ),
	  .WR_DONE                     (wr_burst_finish                           ),
	  .RD_START                    (rd_burst_req                              ),
	  .RD_ADRS                     ({rd_burst_addr,5'd0}                      ),
	  .RD_LEN                      ({rd_burst_len, 5'd0}                       ),
	  .RD_READY                    (                                          ),
	  .RD_FIFO_WE                  (rd_burst_data_valid                       ),
	  .RD_FIFO_FULL                (1'b0                                      ),
	  .RD_FIFO_AFULL               (1'b0                                      ),
	  .RD_FIFO_DATA                (rd_burst_data                             ),
	  .RD_DONE                     (rd_burst_finish                           ),
	  .DEBUG                       (                                          )
);


/************************************************************
通道仲裁模块
************************************************************/ 
//读仲裁
mem_read_arbi 
#(
	.MEM_DATA_BITS               (MEM_DATA_BITS),
	.ADDR_BITS                   (ADDR_BITS    ),
	.BUSRT_BITS                  (BUSRT_BITS   )
)
mem_read_arbi_m0
(
	.rst_n                        (ddr_init_done),
	.mem_clk                      (core_clk),
	.ch0_rd_burst_req             (ch0_rd_burst_req),
	.ch0_rd_burst_len             (ch0_rd_burst_len),
	.ch0_rd_burst_addr            (ch0_rd_burst_addr),
	.ch0_rd_burst_data_valid      (ch0_rd_burst_data_valid),
	.ch0_rd_burst_data            (ch0_rd_burst_data),
	.ch0_rd_burst_finish          (ch0_rd_burst_finish),
	
	.ch1_rd_burst_req             (ch1_rd_burst_req),
	.ch1_rd_burst_len             (ch1_rd_burst_len),
	.ch1_rd_burst_addr            (ch1_rd_burst_addr),
	.ch1_rd_burst_data_valid      (ch1_rd_burst_data_valid),
	.ch1_rd_burst_data            (ch1_rd_burst_data),
	.ch1_rd_burst_finish          (ch1_rd_burst_finish),

	.ch2_rd_burst_req             (ch2_rd_burst_req),
	.ch2_rd_burst_len             (ch2_rd_burst_len),
	.ch2_rd_burst_addr            (ch2_rd_burst_addr),
	.ch2_rd_burst_data_valid      (ch2_rd_burst_data_valid),
	.ch2_rd_burst_data            (ch2_rd_burst_data),
	.ch2_rd_burst_finish          (ch2_rd_burst_finish),

	.ch3_rd_burst_req             (ch3_rd_burst_req),
	.ch3_rd_burst_len             (ch3_rd_burst_len),
	.ch3_rd_burst_addr            (ch3_rd_burst_addr),
	.ch3_rd_burst_data_valid      (ch3_rd_burst_data_valid),
	.ch3_rd_burst_data            (ch3_rd_burst_data),
	.ch3_rd_burst_finish          (ch3_rd_burst_finish),

	.rd_burst_req                 (rd_burst_req),
	.rd_burst_len                 (rd_burst_len),
	.rd_burst_addr                (rd_burst_addr),
	.rd_burst_data_valid          (rd_burst_data_valid),
	.rd_burst_data                (rd_burst_data),
	.rd_burst_finish              (rd_burst_finish)	
);
//写仲裁
mem_write_arbi
#(
	.MEM_DATA_BITS               (MEM_DATA_BITS),
	.ADDR_BITS                   (ADDR_BITS    ),
	.BUSRT_BITS                  (BUSRT_BITS   )
)
mem_write_arbi_m0(
	.rst_n                       (ddr_init_done),
	.mem_clk                     (core_clk),
	
	.ch0_wr_burst_req            (ch0_wr_burst_req),
	.ch0_wr_burst_len            (ch0_wr_burst_len),
	.ch0_wr_burst_addr           (ch0_wr_burst_addr),
	.ch0_wr_burst_data_req       (ch0_wr_burst_data_req),
	.ch0_wr_burst_data           (ch0_wr_burst_data),
	.ch0_wr_burst_finish         (ch0_wr_burst_finish),
	
	.ch1_wr_burst_req            (ch1_wr_burst_req),
	.ch1_wr_burst_len            (ch1_wr_burst_len),
	.ch1_wr_burst_addr           (ch1_wr_burst_addr),
	.ch1_wr_burst_data_req       (ch1_wr_burst_data_req),
	.ch1_wr_burst_data           (ch1_wr_burst_data),
	.ch1_wr_burst_finish         (ch1_wr_burst_finish),

	.ch2_wr_burst_req            (ch2_wr_burst_req),
	.ch2_wr_burst_len            (ch2_wr_burst_len),
	.ch2_wr_burst_addr           (ch2_wr_burst_addr),
	.ch2_wr_burst_data_req       (ch2_wr_burst_data_req),
	.ch2_wr_burst_data           (ch2_wr_burst_data),
	.ch2_wr_burst_finish         (ch2_wr_burst_finish),
	
	.ch3_wr_burst_req            (ch3_wr_burst_req),
	.ch3_wr_burst_len            (ch3_wr_burst_len),
	.ch3_wr_burst_addr           (ch3_wr_burst_addr),
	.ch3_wr_burst_data_req       (ch3_wr_burst_data_req),
	.ch3_wr_burst_data           (ch3_wr_burst_data),
	.ch3_wr_burst_finish         (ch3_wr_burst_finish),
	
	

	.wr_burst_req(wr_burst_req),
	.wr_burst_len(wr_burst_len),
	.wr_burst_addr(wr_burst_addr),
	.wr_burst_data_req(wr_burst_data_req),
	.wr_burst_data(wr_burst_data),
	.wr_burst_finish(wr_burst_finish)	
);

//心跳信号
     always@(posedge core_clk) begin
        if (!ddr_init_done)
            cnt <= 27'd0;
        else if ( cnt >= TH_1S )
            cnt <= 27'd0;
        else
            cnt <= cnt + 27'd1;
     end

     always @(posedge core_clk)
        begin
        if (!ddr_init_done)
            heart_beat_led <= 1'd1;
        else if ( cnt >= TH_1S )
            heart_beat_led <= ~heart_beat_led;
    end
                 
/////////////////////////////////////////////////////////////////////////////////////
//-----------------------------------数据打包-----------------------------------
parameter	IMG_WIDTH	=	1920	;
parameter	IMG_HEIGHT	=	1080	;
parameter	PPC			=	1		;
parameter	PIXCEL_BYTES=	2		;	
parameter	DMA_LEN		=	3840	;	//字节
parameter	IMG_SIZE	=	IMG_WIDTH*IMG_HEIGHT*PIXCEL_BYTES;
parameter	SEND_TIMES	=	IMG_SIZE/DMA_LEN	;

wire              w_video_crtl_de    /* synthesis PAP_MARK_DEBUG="true" */;
wire              w_video_crtl_vs    ;
wire    [23:0]    w_video_crtl_data  /* synthesis PAP_MARK_DEBUG="true" */;
wire    [15:0]    rgb_565_data       ;
wire              w_start_flag       /* synthesis PAP_MARK_DEBUG="true" */;
wire              w_dma_rd_en        /* synthesis PAP_MARK_DEBUG="true" */;
wire    [127:0]   w_dma_rd_data      ;

wire                  video_crtl_vs      ;   
wire                  video_crtl_de      /* synthesis PAP_MARK_DEBUG="true" */; 
wire				  dma_tx_done		 /* synthesis PAP_MARK_DEBUG="true" */;  
video_crtl#(
	.PPC				  ( PPC	),
    .DATA_WIDTH           ( 16  ),
    .IMG_WIDTH            ( IMG_WIDTH ),
    .IMG_HEIGHT           ( IMG_HEIGHT )
)u_video_crtl(
    .i_video_clk          ( pix_clk             ),
    .i_rst_n              ( ddr_init_done       ),
    .i_start_dma_tx_flag  ( w_start_flag        ),
    .i_video_data         ( v3_data             ),
    .i_video_vs           ( v3_vs               ),
    .i_video_de           ( v3_de               ),
    .o_video_crtl_data    ( w_video_crtl_data   ),
    .o_video_crtl_vs      ( w_video_crtl_vs     ),
    .o_video_crtl_de      ( w_video_crtl_de     )
);

//vs复位fifo 避免错位
reg             r_video_crtl_vs_d0     ;
reg    [7:0]    r_vs_ext_cnt           ;      //扩展
reg             r_vs_rst               ;      //复位
reg             r_vs_en                ;
always@(posedge pixclk_in)    begin

    r_video_crtl_vs_d0    <=    w_video_crtl_vs;
end


always@(posedge pixclk_in)    begin
    if(!rstn_out)    
        r_vs_en    <=    1'd0    ;
    else    if(r_vs_ext_cnt == 20 && r_vs_en)
        r_vs_en    <=    1'd0    ;
    else    if(w_video_crtl_vs && ~r_video_crtl_vs_d0)
        r_vs_en    <=    1'd1    ;
    else
        r_vs_en    <=    r_vs_en ;
end


always@(posedge pixclk_in)    begin
    if(!rstn_out)    begin
        r_vs_ext_cnt    <=    'd0    ;
        r_vs_rst        <=    'd0    ;
    end
    else    if(r_vs_ext_cnt == 20 && r_vs_en)    begin
        r_vs_ext_cnt    <=    'd0    ;
        r_vs_rst        <=    'd0    ;
    end
    else    if(r_vs_en)    begin
        r_vs_ext_cnt    <=    r_vs_ext_cnt + 1'b1    ;
        r_vs_rst        <=    1'd1                   ;
    end
    else    begin
        r_vs_ext_cnt    <=    r_vs_ext_cnt    ;
        r_vs_rst        <=    r_vs_rst    ;
    end
end

assign rgb_565_data = {w_video_crtl_data[23:19],w_video_crtl_data[15:10],w_video_crtl_data[7:3]};

reg [15:0]		wr_cnt			/* synthesis PAP_MARK_DEBUG="true" */;
reg	[15:0]		rd_cnt			/* synthesis PAP_MARK_DEBUG="true" */;
reg             r_line_reg      /* synthesis PAP_MARK_DEBUG="true" */;

//hdmi时钟下
reg				r_video_dma_req_pix_d0	/* synthesis PAP_MARK_DEBUG="true" */;
reg				r_video_dma_req_pix_d1	/* synthesis PAP_MARK_DEBUG="true" */;
reg				r_video_dma_req_pix_d2	/* synthesis PAP_MARK_DEBUG="true" */;

//pcie时钟下
//reg             video_dma_req   /* synthesis PAP_MARK_DEBUG="true" */;
wire            video_dma_req       ;
reg             video_dma_req_d0    ;
reg				r_line_req_d0	/* synthesis PAP_MARK_DEBUG="true" */;
reg				r_line_req_d1	/* synthesis PAP_MARK_DEBUG="true" */;
reg				r_line_req_d2	/* synthesis PAP_MARK_DEBUG="true" */;
reg             r_frame_done_d0    ;
reg             r_frame_done_d1    ;
reg             r_frame_done_d2    ;
reg             frame_done         /* synthesis PAP_MARK_DEBUG="true" */;
reg    [15:0]   frame_cnt          /* synthesis PAP_MARK_DEBUG="true" */;
//reg    [63:0]   video_dma_addr     /* synthesis PAP_MARK_DEBUG="true" */;
wire   [63:0]   video_dma_addr     /* synthesis PAP_MARK_DEBUG="true" */;
reg    [63:0]   video_ch0_base_addr/* synthesis PAP_MARK_DEBUG="true" */;
reg    [1:0]    r_wr_index         /* synthesis PAP_MARK_DEBUG="true" */;
reg    [1:0]    r_wr_index_d0      /* synthesis PAP_MARK_DEBUG="true" */;
wire            dma_cmd_rdy        ;
wire            dma_tx_done        ;
wire   [9:0]    video_dma_len      ; 
wire            set_dma_config_en  ;
wire   [63:0]   ch0_dma_base_addr  ;
wire   [63:0]   ch0_dma_base_addr2 ;
wire   [63:0]   ch0_dma_base_addr3 ;
wire   [63:0]   ch0_dma_base_addr4 ;

//hdmi时钟下
always@(posedge    pixclk_in)    begin
	r_video_dma_req_pix_d0	<=	video_dma_req	;
	r_video_dma_req_pix_d1	<=	r_video_dma_req_pix_d0	;
	r_video_dma_req_pix_d2	<=	r_video_dma_req_pix_d1	;
end


//pcie时钟下
always@(posedge    pclk_div2)    begin

	video_dma_req_d0	    <=	video_dma_req;
	r_line_req_d0		    <=	r_line_reg	;
	r_line_req_d1		    <=	r_line_req_d0	;
	r_line_req_d2		    <=	r_line_req_d1	;

	r_frame_done_d0			<=	frame_done	;
	r_frame_done_d1			<=	r_frame_done_d0	;
	r_frame_done_d2			<=	r_frame_done_d1	;

end


//是否发送一帧
always@(posedge    pclk_div2)    begin
    if(!core_rst_n || !w_start_flag || r_vs_rst)
		frame_cnt	<=	'd0	;
	else	if(w_start_flag==0)
		frame_cnt	<=	'd0;
	else	if(dma_tx_done && frame_cnt == SEND_TIMES-1)	//一帧
		frame_cnt	<=	'd0	;
	else	if(dma_tx_done)	//一次是3840字节  
		frame_cnt	<=	frame_cnt + 1'b1	;
	else
		frame_cnt	<=	frame_cnt;
end

//一帧发送完成 发送标志信号
always@(posedge    pclk_div2)    begin
    if(!core_rst_n)
		frame_done	<=	'd0;
	else	if(w_start_flag==0)
		frame_done	<=	'd0;
	else	if(dma_tx_done && frame_cnt == SEND_TIMES-1)	//一帧
		frame_done	<=	'd1;
	else
		frame_done	<=	'd0;

end


//帧空间切换
always@(posedge    pclk_div2)    begin
    if(!core_rst_n || !w_start_flag)
        r_wr_index    <=    'd0    ;
    else    if(frame_done)
        r_wr_index    <=    r_wr_index + 1'b1;
    else
        r_wr_index    <=    r_wr_index    ;
end

//寄存写完的帧号
always@(posedge    pclk_div2)    begin
    if(!core_rst_n || !w_start_flag)
        r_wr_index_d0    <=    'd0    ;
    else    if(frame_done)
        r_wr_index_d0    <=    r_wr_index    ;
    else
        r_wr_index_d0    <=    r_wr_index_d0    ;       
end


assign video_dma_len = DMA_LEN>>2    ;    //dw

//----------------------------------------------------------tx fun ----------------------------------------------------------
wire    [31:0]    o_check_data    ;
wire    [1:0]     o_dma_wr_index  ;
wire              o_dma_wr_done   ;
pcie_tx_fun#(
    .IMG_WIDTH        ( IMG_WIDTH ),
    .IMG_HEIGHT       ( IMG_HEIGHT ),
    .DMA_ADDR_WIDTH   ( 64   ),
    .VIDEO_DATA_WIDTH ( 16   ),
    .PCIE_DATA_WIDTH  ( 128  ),
    .PPC              ( 1    ),
    .PIXCEL_BYTES     ( 2    ),
    .DMA_LEN          ( DMA_LEN )
)u_pcie_tx_fun(
    .i_pcie_clk       ( pclk_div2         ),
    .i_pcie_rst_n     ( core_rst_n        ),
    .i_dma_base_addr  ( ch0_dma_base_addr ),
    .i_dma_base_addr2 ( ch0_dma_base_addr2),
    .i_dma_base_addr3 ( ch0_dma_base_addr3),
    .i_dma_base_addr4 ( ch0_dma_base_addr4),
    .i_dma_len        ( DMA_LEN             ),
    .i_dma_set_en     ( set_dma_config_en),
    .o_dma_wr_index   ( o_dma_wr_index   ),
    .o_dma_wr_done    ( o_dma_wr_done    ),
    .i_start_tx_flag  ( w_start_flag     ),
    .o_check_data     ( o_check_data     ),
    .i_dma_cmd_rdy    ( dma_cmd_rdy      ),
    .o_dma_req        ( video_dma_req    ),
    .o_dma_addr       ( video_dma_addr   ),
    .o_dma_len        (         ),
    .i_dma_tx_done    ( dma_tx_done      ),
    .i_video_clk      ( pix_clk          ),
    .i_video_rst_n    ( ddr_init_done    ),
    .i_video_data     ( w_video_crtl_data),
    .i_video_vs       ( w_video_crtl_vs  ),
    .i_video_de       ( w_video_crtl_de  ),
    .o_dma_rd_data    ( w_dma_rd_data    ),
    .i_dma_rd_en      ( w_dma_rd_en      )
);

//----------------------------------------------------------pcie ----------------------------------------------------------
localparam  DEVICE_TYPE   = 3'b000  ;//@IPC enum 3'b000,3'b001,3'b100
localparam  AXIS_SLAVE_NUM = 3      ;  //@IPC enum 1 2 3
//TEST UNIT MODE SIGNALS
wire            pcie_cfg_ctrl_en        ;
wire            axis_master_tready_cfg  ;

wire            cfg_axis_slave0_tvalid  ;
wire    [127:0] cfg_axis_slave0_tdata   ;
wire            cfg_axis_slave0_tlast   ;
wire            cfg_axis_slave0_tuser   ;

//for mux
wire            axis_master_tready_mem  ;
wire            axis_master_tvalid_mem  ;
wire    [127:0] axis_master_tdata_mem   ;
wire    [3:0]   axis_master_tkeep_mem   ;
wire            axis_master_tlast_mem   ;
wire    [7:0]   axis_master_tuser_mem   ;

wire            cross_4kb_boundary      ;

wire            dma_axis_slave0_tvalid  ;
wire    [127:0] dma_axis_slave0_tdata   ;
wire            dma_axis_slave0_tlast   ;
wire            dma_axis_slave0_tuser   ;

//RESET DEBOUNCE and SYNC
wire            sync_button_rst_n       ;
wire            s_pclk_rstn             ;
wire            s_pclk_div2_rstn        ;

//********************** internal signal
//clk and rst
wire            pclk_div2               ;
wire            pclk                    ;
wire            ref_clk                 ;
wire            core_rst_n              ;
//AXIS master interface
wire            axis_master_tvalid      ;
wire            axis_master_tready      ;
wire    [127:0] axis_master_tdata       ;
wire    [3:0]   axis_master_tkeep       ;
wire            axis_master_tlast       ;
wire    [7:0]   axis_master_tuser       ;

//axis slave 0 interface
wire            axis_slave0_tready      ;
wire            axis_slave0_tvalid      ;
wire    [127:0] axis_slave0_tdata       ;
wire            axis_slave0_tlast       ;
wire            axis_slave0_tuser       ;

//axis slave 1 interface
wire            axis_slave1_tready      ;
wire            axis_slave1_tvalid      ;
wire    [127:0] axis_slave1_tdata       ;
wire            axis_slave1_tlast       ;
wire            axis_slave1_tuser       ;

//axis slave 2 interface
wire            axis_slave2_tready      ;
wire            axis_slave2_tvalid      ;
wire    [127:0] axis_slave2_tdata       ;
wire            axis_slave2_tlast       ;
wire            axis_slave2_tuser       ;

wire    [7:0]   cfg_pbus_num            ;
wire    [4:0]   cfg_pbus_dev_num        ;
wire    [2:0]   cfg_max_rd_req_size     ;
wire    [2:0]   cfg_max_payload_size    ;
wire            cfg_rcb                 ;

wire            cfg_ido_req_en          ;
wire            cfg_ido_cpl_en          ;
wire    [7:0]   xadm_ph_cdts            ;
wire    [11:0]  xadm_pd_cdts            ;
wire    [7:0]   xadm_nph_cdts           ;
wire    [11:0]  xadm_npd_cdts           ;
wire    [7:0]   xadm_cplh_cdts          ;
wire    [11:0]  xadm_cpld_cdts          ;

//system signal
wire    [4:0]   smlh_ltssm_state        ;

// led lights up
reg     [22:0]  ref_led_cnt             ;
reg     [26:0]  pclk_led_cnt            ;

//uart2apb 32bits
wire            uart_p_sel              ;
wire    [3:0]   uart_p_strb             ;
wire    [15:0]  uart_p_addr             ;
wire    [31:0]  uart_p_wdata            ;
wire            uart_p_ce               ;
wire            uart_p_we               ;
wire            uart_p_rdy              ;
wire    [31:0]  uart_p_rdata            ;

//apb
wire    [3:0]   p_strb                  ;
wire    [15:0]  p_addr                  ;
wire    [31:0]  p_wdata                 ;
wire            p_ce                    ;
wire            p_we                    ;

//apb mux
wire            p_sel_pcie              ;       //0~5:hsstlp 6:Reserved 7:pcie
wire            p_sel_cfg               ;       //8: cfg
wire            p_sel_dma               ;       //9: dma

wire    [31:0]  p_rdata_pcie            ;       //0~5:hsstlp 6:Reserved 7:pcie
wire    [31:0]  p_rdata_cfg             ;       //8: cfg
wire    [31:0]  p_rdata_dma             ;       //9: dma

wire            p_rdy_pcie              ;       //0~5:hsstlp 6:Reserved 7:pcie
wire            p_rdy_cfg               ;       //8: cfg
wire            p_rdy_dma               ;       //9: dma

wire            start_flag              ;       //开始采集标志

assign cfg_ido_req_en   =   1'b0;
assign cfg_ido_cpl_en   =   1'b0;
assign xadm_ph_cdts     =   8'b0;
assign xadm_pd_cdts     =   12'b0;
assign xadm_nph_cdts    =   8'b0;
assign xadm_npd_cdts    =   12'b0;
assign xadm_cplh_cdts   =   8'b0;
assign xadm_cpld_cdts   =   12'b0;
//ASYNC RST  define IPS2L_PCIE_SPEEDUP_SIM when simulation
hsst_rst_cross_sync_v1_0 #(
    `ifdef IPS2L_PCIE_SPEEDUP_SIM
    .RST_CNTR_VALUE     (16'h10             )
    `else
    .RST_CNTR_VALUE     (16'hC000           )
    `endif
)
u_refclk_buttonrstn_debounce(
    .clk                (ref_clk            ),
    .rstn_in            (button_rst_n       ),
    .rstn_out           (sync_button_rst_n  )
);

hsst_rst_cross_sync_v1_0 #(
    `ifdef IPS2L_PCIE_SPEEDUP_SIM
    .RST_CNTR_VALUE     (16'h10             )
    `else
    .RST_CNTR_VALUE     (16'hC000           )
    `endif
)
u_refclk_perstn_debounce(
    .clk                (ref_clk            ),
    .rstn_in            (perst_n            ),
    .rstn_out           (sync_perst_n       )
);

hsst_rst_sync_v1_0  u_ref_core_rstn_sync    (
    .clk                (ref_clk            ),
    .rst_n              (core_rst_n         ),
    .sig_async          (1'b1               ),
    .sig_synced         (ref_core_rst_n     )
);

hsst_rst_sync_v1_0  u_pclk_core_rstn_sync   (
    .clk                (pclk               ),
    .rst_n              (core_rst_n         ),
    .sig_async          (1'b1               ),
    .sig_synced         (s_pclk_rstn        )
);


always @(posedge ref_clk or negedge sync_perst_n)
begin
    if (!sync_perst_n)
        ref_led_cnt    <= 23'd0;
    else
        ref_led_cnt    <= ref_led_cnt + 23'd1;
end

always @(posedge ref_clk or negedge sync_perst_n)
begin
    if (!sync_perst_n)
        ref_led        <= 1'b1;
    else if(&ref_led_cnt)
        ref_led        <= ~ref_led;
end

always @(posedge pclk or negedge s_pclk_rstn)
begin
    if (!s_pclk_rstn)
        pclk_led_cnt    <= 27'd0;
    else
        pclk_led_cnt    <= pclk_led_cnt + 27'd1;
end

always @(posedge pclk or negedge s_pclk_rstn)
begin
    if (!s_pclk_rstn)
        pclk_led        <= 1'b1;
    else if(&pclk_led_cnt)
        pclk_led        <= ~pclk_led;
end


//----------------------------------------------------------   pcie pio  ----------------------------------------------------------
wire            pio_wr_en      ;
wire    [9:0]   pio_wr_addr    ;
wire    [31:0]  pio_wr_data    ;

wire            pio_rd_en      ;
wire    [9:0]   pio_rd_addr    ;
wire    [31:0]  pio_rd_data    ;            
pio_crtl u_pio_crtl(
    .pcie_clk              ( pclk_div2         ),
    .rst_n                 ( core_rst_n        ),
    .start_flag            ( w_start_flag      ),
    .set_dma_config_en     ( set_dma_config_en ),
    .o_ch0_base_addr       ( ch0_dma_base_addr ),
    .o_ch0_base_addr2      ( ch0_dma_base_addr2),
    .o_ch0_base_addr3      ( ch0_dma_base_addr3),
    .o_ch0_base_addr4      ( ch0_dma_base_addr4),
    .i_wr_frame_done       ( o_dma_wr_done     ),
    .i_wr_index            ( o_dma_wr_index    ),
    .pio_wr_en             ( pio_wr_en         ),
    .pio_wr_addr           ( pio_wr_addr       ),
    .pio_wr_data           ( pio_wr_data       ),
    .pio_rd_en             ( pio_rd_en         ),
    .pio_rd_addr           ( pio_rd_addr       ),
    .pio_rd_data           ( pio_rd_data       )
);

//----------------------------------------------------------   pcie dma  ----------------------------------------------------------

// DMA CTRL      BASE ADDR = 0x8000
ips2l_pcie_dma #(
    .DEVICE_TYPE            (DEVICE_TYPE            ),
    .AXIS_SLAVE_NUM         (AXIS_SLAVE_NUM         )
)
u_ips2l_pcie_dma
(
    .clk                    (pclk_div2              ),  //gen1:62.5MHz,gen2:125MHz
    .rst_n                  (core_rst_n             ),
    //**********************************************************************
    .i_video_dma_req        (video_dma_req          ),
    .i_video_dma_addr       (video_dma_addr         ),
    .i_video_dma_len        (video_dma_len          ),
    .i_dma_32or64           (0                      ),    //64bit
    .o_dma_cmd_rdy          (dma_cmd_rdy            ),
    .o_dma_tx_done          (dma_tx_done            ),
    .o_ch0_base_addr        (      ),
    //dma
    .o_dma_rd_en            (w_dma_rd_en            ),
    .i_dma_rd_data          (w_dma_rd_data          ),
    .o_dma_wr_en            (dma_wr_en              ),
    .o_dma_wr_data          (dma_wr_data            ),
    //pio
    .o_pio_wr_en            (pio_wr_en              ),
    .o_pio_wr_addr          (pio_wr_addr            ),
    .o_pio_wr_data          (pio_wr_data            ),                            
    .o_pio_rd_en            (pio_rd_en              ),
    .o_pio_rd_addr          (pio_rd_addr            ),
    .o_pio_rd_data          (pio_rd_data            ),
    //**********************************************************************
    //num
    .i_cfg_pbus_num         (cfg_pbus_num           ),  //input [7:0]
    .i_cfg_pbus_dev_num     (cfg_pbus_dev_num       ),  //input [4:0]
    .i_cfg_max_rd_req_size  (cfg_max_rd_req_size    ),  //input [2:0]
    .i_cfg_max_payload_size (cfg_max_payload_size   ),  //input [2:0]
    //**********************************************************************
    //axis master interface
    .i_axis_master_tvld     (axis_master_tvalid_mem ),
    .o_axis_master_trdy     (axis_master_tready_mem ),
    .i_axis_master_tdata    (axis_master_tdata_mem  ),
    .i_axis_master_tkeep    (axis_master_tkeep_mem  ),
    .i_axis_master_tlast    (axis_master_tlast_mem  ),
    .i_axis_master_tuser    (axis_master_tuser_mem  ),

    //**********************************************************************
    //axis_slave0 interface
    .i_axis_slave0_trdy     (axis_slave0_tready     ),
    .o_axis_slave0_tvld     (dma_axis_slave0_tvalid ),
    .o_axis_slave0_tdata    (dma_axis_slave0_tdata  ),
    .o_axis_slave0_tlast    (dma_axis_slave0_tlast  ),
    .o_axis_slave0_tuser    (dma_axis_slave0_tuser  ),
    //axis_slave1 interface
    .i_axis_slave1_trdy     (axis_slave1_tready     ),
    .o_axis_slave1_tvld     (axis_slave1_tvalid     ),
    .o_axis_slave1_tdata    (axis_slave1_tdata      ),
    .o_axis_slave1_tlast    (axis_slave1_tlast      ),
    .o_axis_slave1_tuser    (axis_slave1_tuser      ),
    //axis_slave2 interface
    .i_axis_slave2_trdy     (axis_slave2_tready     ),
    .o_axis_slave2_tvld     (axis_slave2_tvalid     ),
    .o_axis_slave2_tdata    (axis_slave2_tdata      ),
    .o_axis_slave2_tlast    (axis_slave2_tlast      ),
    .o_axis_slave2_tuser    (axis_slave2_tuser      ),
    //from pcie
    .i_cfg_ido_req_en       (cfg_ido_req_en         ),
    .i_cfg_ido_cpl_en       (cfg_ido_cpl_en         ),
    .i_xadm_ph_cdts         (xadm_ph_cdts           ),
    .i_xadm_pd_cdts         (xadm_pd_cdts           ),
    .i_xadm_nph_cdts        (xadm_nph_cdts          ),
    .i_xadm_npd_cdts        (xadm_npd_cdts          ),
    .i_xadm_cplh_cdts       (xadm_cplh_cdts         ),
    .i_xadm_cpld_cdts       (xadm_cpld_cdts         ),
    //**********************************************************************
    //apb interface
    .i_apb_psel             (p_sel_dma              ),
    .i_apb_paddr            (p_addr[8:0]            ),
    .i_apb_pwdata           (p_wdata                ),
    .i_apb_pstrb            (p_strb                 ),
    .i_apb_pwrite           (p_we                   ),
    .i_apb_penable          (p_ce                   ),
    .o_apb_prdy             (p_rdy_dma              ),
    .o_apb_prdata           (p_rdata_dma            ),
    .o_cross_4kb_boundary   (cross_4kb_boundary     )
);

generate
    if (DEVICE_TYPE == 3'd4)
    begin:rc
    //----------------------------------------------------------   cfg ctrl  ----------------------------------------------------------
    //CFG TLP TX RX     BASE ADDR = 0x9000
        pcie_cfg_ctrl   u_pcie_cfg_ctrl(
            //from APB
            .pclk_div2              (pclk_div2              ),
            .apb_rst_n              (core_rst_n             ),
            .p_sel                  (p_sel_cfg              ),
            .p_strb                 (p_strb                 ),
            .p_addr                 (p_addr[7:0]            ),
            .p_wdata                (p_wdata                ),
            .p_ce                   (p_ce                   ),
            .p_we                   (p_we                   ),
            .p_rdy                  (p_rdy_cfg              ),
            .p_rdata                (p_rdata_cfg            ),
            .pcie_cfg_ctrl_en       (pcie_cfg_ctrl_en       ),
            //to PCIE ctrl
            .axis_slave_tready      (axis_slave0_tready     ),
            .axis_slave_tvalid      (cfg_axis_slave0_tvalid ),
            .axis_slave_tlast       (cfg_axis_slave0_tlast  ),
            .axis_slave_tuser       (cfg_axis_slave0_tuser  ),
            .axis_slave_tdata       (cfg_axis_slave0_tdata  ),
            
            .axis_master_tready     (axis_master_tready_cfg ),
            .axis_master_tvalid     (axis_master_tvalid     ),
            .axis_master_tlast      (axis_master_tlast      ),
        //    .axis_master_tuser      (axis_master_tuser      ),
            .axis_master_tkeep      (axis_master_tkeep      ),
            .axis_master_tdata      (axis_master_tdata      )
        );

        //----------------------------------------------------------   logic mux  ----------------------------------------------------------
        assign axis_slave0_tvalid      = pcie_cfg_ctrl_en ? cfg_axis_slave0_tvalid  : dma_axis_slave0_tvalid;
        assign axis_slave0_tlast       = pcie_cfg_ctrl_en ? cfg_axis_slave0_tlast   : dma_axis_slave0_tlast;
        assign axis_slave0_tuser       = pcie_cfg_ctrl_en ? cfg_axis_slave0_tuser   : dma_axis_slave0_tuser;
        assign axis_slave0_tdata       = pcie_cfg_ctrl_en ? cfg_axis_slave0_tdata   : dma_axis_slave0_tdata;

        assign axis_master_tvalid_mem  = pcie_cfg_ctrl_en ? 1'b0                    : axis_master_tvalid;
        assign axis_master_tdata_mem   = pcie_cfg_ctrl_en ? 128'b0                  : axis_master_tdata;
        assign axis_master_tkeep_mem   = pcie_cfg_ctrl_en ? 4'b0                    : axis_master_tkeep;
        assign axis_master_tlast_mem   = pcie_cfg_ctrl_en ? 1'b0                    : axis_master_tlast;
        assign axis_master_tuser_mem   = pcie_cfg_ctrl_en ? 8'b0                    : axis_master_tuser;
        
        assign axis_master_tready      = pcie_cfg_ctrl_en ? axis_master_tready_cfg  : axis_master_tready_mem;
    end
    else
    begin:ep
        assign p_rdy_cfg               = 1'b0;
        assign p_rdata_cfg             = 32'b0;

        assign axis_slave0_tvalid      = dma_axis_slave0_tvalid;
        assign axis_slave0_tlast       = dma_axis_slave0_tlast;
        assign axis_slave0_tuser       = dma_axis_slave0_tuser;
        assign axis_slave0_tdata       = dma_axis_slave0_tdata;

        assign axis_master_tvalid_mem  = axis_master_tvalid;
        assign axis_master_tdata_mem   = axis_master_tdata;
        assign axis_master_tkeep_mem   = axis_master_tkeep;
        assign axis_master_tlast_mem   = axis_master_tlast;
        assign axis_master_tuser_mem   = axis_master_tuser;
        
        assign axis_master_tready      = axis_master_tready_mem;
    end
endgenerate

//----------------------------------------------------------   pcie wrap  ----------------------------------------------------------
//pcie wrap : HSSTLP : 0x0000~6000 PCIe BASE ADDR : 0x7000
pcie_test
u_ips2l_pcie_wrap
(
    .button_rst_n               (sync_button_rst_n      ),
    .power_up_rst_n             (sync_perst_n           ),
    .perst_n                    (sync_perst_n           ),
    //clk and rst
    .pclk                       (pclk                   ),      //output
    .pclk_div2                  (pclk_div2              ),      //output
    .ref_clk                    (ref_clk                ),      //output
    .ref_clk_n                  (ref_clk_n              ),      //input
    .ref_clk_p                  (ref_clk_p              ),      //input
    .core_rst_n                 (core_rst_n             ),      //output
    
    //APB interface to  DBI cfg
    //.p_clk                      (ref_clk                ),      //input
    .p_sel                      (p_sel_pcie             ),      //input
    .p_strb                     (uart_p_strb            ),      //input  [ 3:0]
    .p_addr                     (uart_p_addr            ),      //input  [15:0]
    .p_wdata                    (uart_p_wdata           ),      //input  [31:0]
    .p_ce                       (uart_p_ce              ),      //input
    .p_we                       (uart_p_we              ),      //input
    .p_rdy                      (p_rdy_pcie             ),      //output
    .p_rdata                    (p_rdata_pcie           ),      //output [31:0]
    
    //PHY diff signals
    .rxn                        (rxn                    ),      //input   [3:0]
    .rxp                        (rxp                    ),      //input   [3:0]
    .txn                        (txn                    ),      //output  [3:0]
    .txp                        (txp                    ),      //output  [3:0]
    
    .pcs_nearend_loop           ({2{1'b0}}              ),      //input
    .pma_nearend_ploop          ({2{1'b0}}              ),      //input
    .pma_nearend_sloop          ({2{1'b0}}              ),      //input
    
    //AXIS master interface
    .axis_master_tvalid         (axis_master_tvalid     ),      //output
    .axis_master_tready         (axis_master_tready     ),      //input
    .axis_master_tdata          (axis_master_tdata      ),      //output [127:0]
    .axis_master_tkeep          (axis_master_tkeep      ),      //output [3:0]
    .axis_master_tlast          (axis_master_tlast      ),      //output
    .axis_master_tuser          (axis_master_tuser      ),      //output [7:0]
    
    //axis slave 0 interface
    .axis_slave0_tready         (axis_slave0_tready     ),      //output
    .axis_slave0_tvalid         (axis_slave0_tvalid     ),      //input
    .axis_slave0_tdata          (axis_slave0_tdata      ),      //input  [127:0]
    .axis_slave0_tlast          (axis_slave0_tlast      ),      //input
    .axis_slave0_tuser          (axis_slave0_tuser      ),      //input
    
    //axis slave 1 interface
    .axis_slave1_tready         (axis_slave1_tready     ),      //output
    .axis_slave1_tvalid         (axis_slave1_tvalid     ),      //input
    .axis_slave1_tdata          (axis_slave1_tdata      ),      //input  [127:0]
    .axis_slave1_tlast          (axis_slave1_tlast      ),      //input
    .axis_slave1_tuser          (axis_slave1_tuser      ),      //input
    //axis slave 2 interface
    .axis_slave2_tready         (axis_slave2_tready     ),      //output
    .axis_slave2_tvalid         (axis_slave2_tvalid     ),      //input
    .axis_slave2_tdata          (axis_slave2_tdata      ),      //input  [127:0]
    .axis_slave2_tlast          (axis_slave2_tlast      ),      //input
    .axis_slave2_tuser          (axis_slave2_tuser      ),      //input
     
    .pm_xtlh_block_tlp          (                       ),      //output
    
    .cfg_send_cor_err_mux       (                       ),      //output
    .cfg_send_nf_err_mux        (                       ),      //output
    .cfg_send_f_err_mux         (                       ),      //output
    .cfg_sys_err_rc             (                       ),      //output
    .cfg_aer_rc_err_mux         (                       ),      //output
    //radm timeout
    .radm_cpl_timeout           (                       ),      //output
    
    //configuration signals
    .cfg_max_rd_req_size        (cfg_max_rd_req_size    ),      //output [2:0]
    .cfg_bus_master_en          (                       ),      //output
    .cfg_max_payload_size       (cfg_max_payload_size   ),      //output [2:0]
    .cfg_ext_tag_en             (                       ),      //output
    .cfg_rcb                    (cfg_rcb                ),      //output
    .cfg_mem_space_en           (                       ),      //output
    .cfg_pm_no_soft_rst         (                       ),      //output
    .cfg_crs_sw_vis_en          (                       ),      //output
    .cfg_no_snoop_en            (                       ),      //output
    .cfg_relax_order_en         (                       ),      //output
    .cfg_tph_req_en             (                       ),      //output [2-1:0]
    .cfg_pf_tph_st_mode         (                       ),      //output [3-1:0]
    .rbar_ctrl_update           (                       ),      //output
    .cfg_atomic_req_en          (                       ),      //output
    
    .cfg_pbus_num               (cfg_pbus_num           ),      //output [7:0]
    .cfg_pbus_dev_num           (cfg_pbus_dev_num       ),      //output [4:0]
    
    //debug signals
    .radm_idle                  (                       ),      //output
    .radm_q_not_empty           (                       ),      //output
    .radm_qoverflow             (                       ),      //output
    .diag_ctrl_bus              (2'b0                   ),      //input   [1:0]
    .cfg_link_auto_bw_mux       (                       ),      //output              merge cfg_link_auto_bw_msi and cfg_link_auto_bw_int
    .cfg_bw_mgt_mux             (                       ),      //output              merge cfg_bw_mgt_int and cfg_bw_mgt_msi
    .cfg_pme_mux                (                       ),      //output              merge cfg_pme_int and cfg_pme_msi
    .app_ras_des_sd_hold_ltssm  (1'b0                   ),      //input
    .app_ras_des_tba_ctrl       (2'b0                   ),      //input   [1:0]
    
    .dyn_debug_info_sel         (4'b0                   ),      //input   [3:0]
    .debug_info_mux             (                       ),      //output  [132:0]
    
    //system signal
    .smlh_link_up               (smlh_link_up           ),      //output
    .rdlh_link_up               (rdlh_link_up           ),      //output
    .smlh_ltssm_state           (smlh_ltssm_state       )       //output  [4:0]
);




endmodule
