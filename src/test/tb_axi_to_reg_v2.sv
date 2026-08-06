// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Philippe Sauter <phsauter@iis.ee.ethz.ch>

/// Testbench for axi_to_reg_v2 module
/// Tests both correctness and throughput using:
/// 1. Known pattern tests via axi_driver (sequential read/write with various burst lengths)
/// 2. Random traffic tests via axi_rand_master

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module tb_axi_to_reg_v2
  import axi_pkg::*;
#(
  /// AXI Address width
  parameter int unsigned TbAxiAddrWidth   = 32'd32,
  /// AXI Data width (64-bit for NumBanks=2)
  parameter int unsigned TbAxiDataWidth   = 32'd64,
  /// AXI ID width
  parameter int unsigned TbAxiIdWidth     = 32'd4,
  /// AXI User width
  parameter int unsigned TbAxiUserWidth   = 32'd1,
  /// Register interface data width
  parameter int unsigned TbRegDataWidth   = 32'd32,
  /// Memory size in bytes
  parameter int unsigned TbMemSize        = 32'h10000, // 64KB
  /// Base address of memory
  parameter logic [31:0] TbMemBaseAddr    = 32'h0000_0000,
  /// Number of random write transactions
  parameter int unsigned TbNumWrites      = 32'd1_000,
  /// Number of random read transactions
  parameter int unsigned TbNumReads       = 32'd1_000,
  /// Cycle time for the TB clock generator
  parameter time         TbCyclTime       = 10ns,
  /// Application time to the DUT
  parameter time         TbApplTime       = 2ns,
  /// Test time of the DUT
  parameter time         TbTestTime       = 8ns
);

  /////////////////////////
  // Clock and Reset gen //
  /////////////////////////
  logic clk, rst_n;

  clk_rst_gen #(
    .ClkPeriod    ( TbCyclTime ),
    .RstClkCycles ( 32'd5      )
  ) i_clk_rst_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  //////////////////////////
  // Type definitions     //
  //////////////////////////
  typedef logic [TbAxiAddrWidth-1:0]   axi_addr_t;
  typedef logic [TbAxiDataWidth-1:0]   axi_data_t;
  typedef logic [TbAxiDataWidth/8-1:0] axi_strb_t;
  typedef logic [TbAxiIdWidth-1:0]     axi_id_t;
  typedef logic [TbAxiUserWidth-1:0]   axi_user_t;

  // AXI channel typedefs
  `AXI_TYPEDEF_ALL_CT(axi, axi_req_t, axi_rsp_t,
    axi_addr_t, axi_id_t, axi_data_t, axi_strb_t, axi_user_t)

  // Register interface typedefs
  typedef logic [TbAxiAddrWidth-1:0]     reg_addr_t;
  typedef logic [TbRegDataWidth-1:0]     reg_data_t;
  typedef logic [TbRegDataWidth/8-1:0]   reg_strb_t;
  `REG_BUS_TYPEDEF_ALL(reg, reg_addr_t, reg_data_t, reg_strb_t)

  //////////////////////////
  // Signals              //
  //////////////////////////
  axi_req_t axi_req;
  axi_rsp_t axi_rsp;
  reg_req_t reg_req;
  reg_rsp_t reg_rsp;
  axi_id_t  reg_id;
  logic     dut_busy;
  logic     address_mapping_test_active;

  logic end_of_sim;

  // Performance counters
  int unsigned write_count;
  int unsigned read_count;
  int unsigned total_write_cycles;
  int unsigned total_read_cycles;
  int unsigned write_start_cycle;
  int unsigned read_start_cycle;
  int unsigned current_cycle;

  // Error tracking
  int unsigned error_count;

  //////////////////////////
  // AXI Interface        //
  //////////////////////////
  // Non-DV interface for DUT connection
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) axi_bus ();

  // DV interface for driver
  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) axi_dv (
    .clk_i ( clk )
  );

  // Connect DV interface to non-DV interface
  `AXI_ASSIGN(axi_bus, axi_dv)

  // Connect AXI bus to request/response structs
  `AXI_ASSIGN_TO_REQ(axi_req, axi_bus)
  `AXI_ASSIGN_FROM_RESP(axi_bus, axi_rsp)

  //////////////////////////
  // DUT Instantiation    //
  //////////////////////////
  axi_to_reg_v2 #(
    .AxiAddrWidth ( TbAxiAddrWidth ),
    .AxiDataWidth ( TbAxiDataWidth ),
    .AxiIdWidth   ( TbAxiIdWidth   ),
    .AxiUserWidth ( TbAxiUserWidth ),
    .RegDataWidth ( TbRegDataWidth ),
    .CutMemReqs   ( 1'b1           ),
    .CutMemRsps   ( 1'b0           ),
    .axi_req_t    ( axi_req_t      ),
    .axi_rsp_t    ( axi_rsp_t      ),
    .reg_req_t    ( reg_req_t      ),
    .reg_rsp_t    ( reg_rsp_t      )
  ) i_axi_to_reg_v2 (
    .clk_i     ( clk       ),
    .rst_ni    ( rst_n     ),
    .axi_req_i ( axi_req   ),
    .axi_rsp_o ( axi_rsp   ),
    .reg_req_o ( reg_req   ),
    .reg_rsp_i ( reg_rsp   ),
    .reg_id_o  ( reg_id    ),
    .busy_o    ( dut_busy  )
  );

  //////////////////////////
  // Memory Instantiation //
  //////////////////////////
  reg_test_mem #(
    .AddrWidth ( TbAxiAddrWidth ),
    .DataWidth ( TbRegDataWidth ),
    .req_t     ( reg_req_t      ),
    .rsp_t     ( reg_rsp_t      ),
    .MemSize   ( TbMemSize      ),
    .BaseAddr  ( TbMemBaseAddr  )
  ) i_reg_mem (
    .clk_i     ( clk     ),
    .rst_ni    ( rst_n   ),
    .reg_req_i ( reg_req ),
    .reg_rsp_o ( reg_rsp )
  );

  // Check that each register write uses the address encoded in the test data.
  always @(posedge clk) begin
    if (address_mapping_test_active && reg_req.valid && reg_req.write) begin
      if (reg_req.addr !== TbMemBaseAddr + (reg_req.wdata[15:0] * 'h100) +
          (reg_req.wdata[31:16] * (TbRegDataWidth / 8))) begin
        $error("[ADDRESS MAPPING] Expected register address 0x%h, got 0x%h",
               TbMemBaseAddr + (reg_req.wdata[15:0] * 'h100) +
               (reg_req.wdata[31:16] * (TbRegDataWidth / 8)), reg_req.addr);
        error_count++;
      end
    end
  end

  //////////////////////////
  // Test Classes         //
  //////////////////////////

  // AXI driver for controlled tests
  typedef axi_test::axi_driver #(
    .AW ( TbAxiAddrWidth ),
    .DW ( TbAxiDataWidth ),
    .IW ( TbAxiIdWidth   ),
    .UW ( TbAxiUserWidth ),
    .TA ( TbApplTime     ),
    .TT ( TbTestTime     )
  ) axi_driver_t;

  // AXI random master for stress testing
  typedef axi_test::axi_rand_master #(
    .AW                   ( TbAxiAddrWidth ),
    .DW                   ( TbAxiDataWidth ),
    .IW                   ( TbAxiIdWidth   ),
    .UW                   ( TbAxiUserWidth ),
    .TA                   ( TbApplTime     ),
    .TT                   ( TbTestTime     ),
    .MAX_READ_TXNS        ( 8              ),
    .MAX_WRITE_TXNS       ( 8              ),
    .AX_MIN_WAIT_CYCLES   ( 0              ),
    .AX_MAX_WAIT_CYCLES   ( 5              ),
    .W_MIN_WAIT_CYCLES    ( 0              ),
    .W_MAX_WAIT_CYCLES    ( 2              ),
    .RESP_MIN_WAIT_CYCLES ( 0              ),
    .RESP_MAX_WAIT_CYCLES ( 5              ),
    .AXI_BURST_FIXED      ( 1'b0           ),
    .AXI_BURST_INCR       ( 1'b1           ),
    .AXI_BURST_WRAP       ( 1'b0           ),
    .AXI_MAX_BURST_LEN    ( 16             ),
    .SIZE_ALIGN           ( 1              )
  ) axi_rand_master_t;

  // AXI scoreboard for checking
  typedef axi_test::axi_scoreboard #(
    .IW ( TbAxiIdWidth   ),
    .AW ( TbAxiAddrWidth ),
    .DW ( TbAxiDataWidth ),
    .UW ( TbAxiUserWidth ),
    .TT ( TbTestTime     )
  ) axi_scoreboard_t;

  //////////////////////////
  // Cycle Counter        //
  //////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_cycle <= 0;
    end else begin
      current_cycle <= current_cycle + 1;
    end
  end

  //////////////////////////
  // Debug Monitor        //
  //////////////////////////
  // Monitor AXI signals for first 100 cycles
  always @(posedge clk) begin
    if (rst_n && current_cycle < 100) begin
      $display({"[%0t] cycle=%0d aw_valid=%b aw_ready=%b w_valid=%b w_ready=%b ",
                "b_valid=%b b_ready=%b"},
               $time, current_cycle, axi_req.aw_valid, axi_rsp.aw_ready,
               axi_req.w_valid, axi_rsp.w_ready, axi_rsp.b_valid, axi_req.b_ready);
    end
  end

  //////////////////////////
  // Test Tasks           //
  //////////////////////////

  // Task to perform a single AXI write transaction (no burst)
  // AW and W are sent in parallel, then waits for B
  // Uses full AXI data width
  task automatic axi_single_write(
    input axi_driver_t  drv,
    input axi_addr_t    addr,
    input axi_data_t    data,       // Full AXI width data
    input logic [2:0]   size
  );
    automatic axi_driver_t::ax_beat_t aw_beat = new;
    automatic axi_driver_t::w_beat_t  w_beat  = new;
    automatic axi_driver_t::b_beat_t  b_beat;

    $display("[DEBUG] axi_single_write: addr=0x%h, data=0x%h, size=%0d",
             addr, data, size);

    // Configure AW beat - single transfer
    aw_beat.ax_addr  = addr;
    aw_beat.ax_len   = 8'h0;        // Single beat (len=0 means 1 transfer)
    aw_beat.ax_size  = size;
    aw_beat.ax_burst = BURST_FIXED; // Fixed burst for single beat
    aw_beat.ax_id    = $urandom();

    // Configure W beat - full width
    w_beat.w_data = data;
    w_beat.w_strb = '1;             // Full strobe for full width access
    w_beat.w_last = 1'b1;           // Single beat, so always last

    // Send AW and W in parallel
    fork
      drv.send_aw(aw_beat);
      drv.send_w(w_beat);
    join

    // Wait for write response
    drv.recv_b(b_beat);
    if (b_beat.b_resp != RESP_OKAY) begin
      $error("[WRITE] Unexpected response: %0d at addr 0x%h", b_beat.b_resp, addr);
      error_count++;
    end
  endtask

  // Task to perform a single AXI read transaction (no burst)
  // Uses full AXI data width
  task automatic axi_single_read(
    input  axi_driver_t drv,
    input  axi_addr_t   addr,
    input  logic [2:0]  size,
    output axi_data_t   data       // Full AXI width data
  );
    automatic axi_driver_t::ax_beat_t ar_beat = new;
    automatic axi_driver_t::r_beat_t  r_beat;

    // Configure AR beat - single transfer
    ar_beat.ax_addr  = addr;
    ar_beat.ax_len   = 8'h0;        // Single beat
    ar_beat.ax_size  = size;
    ar_beat.ax_burst = BURST_FIXED; // Fixed burst for single beat
    ar_beat.ax_id    = $urandom();

    drv.send_ar(ar_beat);
    drv.recv_r(r_beat);

    data = r_beat.r_data;

    if (r_beat.r_resp != RESP_OKAY) begin
      $error("[READ] Unexpected response: %0d at addr 0x%h", r_beat.r_resp, addr);
      error_count++;
    end
    if (!r_beat.r_last) begin
      $error("[READ] Expected RLAST for single beat");
      error_count++;
    end
  endtask

  function automatic axi_data_t address_mapping_data(input int unsigned index);
    axi_data_t data;

    data = '0;
    for (int bank = 0; bank < TbAxiDataWidth / 32; bank++) begin
      data[bank * 32 +: 32] = {bank[15:0], index[15:0]};
    end
    return data;
  endfunction

  // Task to perform a burst AXI write transaction (INCR burst)
  // Writes (burst_len+1) beats of full-width AXI data
  task automatic axi_burst_write(
    input axi_driver_t  drv,
    input axi_addr_t    start_addr,
    input int unsigned  burst_len,    // Number of beats - 1 (AXI encoding)
    input logic [2:0]   size          // Transaction size (should be full bus width)
  );
    automatic axi_driver_t::ax_beat_t aw_beat = new;
    automatic axi_driver_t::w_beat_t  w_beat  = new;
    automatic axi_driver_t::b_beat_t  b_beat;
    // Configure AW beat - burst transfer
    aw_beat.ax_addr  = start_addr;
    aw_beat.ax_len   = burst_len[7:0];
    aw_beat.ax_size  = size;
    aw_beat.ax_burst = BURST_INCR;
    aw_beat.ax_id    = $urandom();

    // axi_to_detailed_mem accepts the first AW only alongside the first W.
    // Keep both AXI write channels active concurrently, as in axi_single_write.
    fork
      drv.send_aw(aw_beat);
      begin
        for (int i = 0; i <= burst_len; i++) begin
          w_beat.w_data = {TbAxiDataWidth/32{32'hB0B0_0000 + i[15:0]}};
          w_beat.w_strb = '1;  // Full strobe
          w_beat.w_last = (i == burst_len);
          drv.send_w(w_beat);
        end
      end
    join

    // Wait for write response
    drv.recv_b(b_beat);
    if (b_beat.b_resp != RESP_OKAY) begin
      $error("[BURST WRITE] Unexpected response: %0d at addr 0x%h", b_beat.b_resp, start_addr);
      error_count++;
    end
  endtask

  // Task to perform a burst AXI read transaction (INCR burst)
  // Reads (burst_len+1) beats of full-width AXI data
  task automatic axi_burst_read(
    input axi_driver_t  drv,
    input axi_addr_t    start_addr,
    input int unsigned  burst_len,    // Number of beats - 1 (AXI encoding)
    input logic [2:0]   size
  );
    automatic axi_driver_t::ax_beat_t ar_beat = new;
    automatic axi_driver_t::r_beat_t  r_beat;

    // Configure AR beat - burst transfer
    ar_beat.ax_addr  = start_addr;
    ar_beat.ax_len   = burst_len[7:0];
    ar_beat.ax_size  = size;
    ar_beat.ax_burst = BURST_INCR;
    ar_beat.ax_id    = $urandom();

    drv.send_ar(ar_beat);

    // Receive R beats
    for (int i = 0; i <= burst_len; i++) begin
      drv.recv_r(r_beat);
      if (r_beat.r_resp != RESP_OKAY) begin
        $error("[BURST READ] Unexpected response: %0d at beat %0d", r_beat.r_resp, i);
        error_count++;
      end
      if ((i == burst_len) && !r_beat.r_last) begin
        $error("[BURST READ] Expected RLAST on final beat");
        error_count++;
      end
    end
  endtask

  //////////////////////////
  // Main Test Process    //
  //////////////////////////
  initial begin : proc_sim_ctrl
    automatic axi_driver_t      axi_drv     = new(axi_dv);
    automatic axi_rand_master_t axi_rand    = new(axi_dv);
    automatic axi_scoreboard_t  scoreboard  = new(axi_dv);

    automatic axi_addr_t test_addr;

    automatic int unsigned test_start_time;
    automatic int unsigned test_end_time;
    automatic real throughput;

    // Size for full AXI width transactions
    automatic logic [2:0] full_size = $clog2(TbAxiDataWidth/8);
    // Number of bytes per AXI beat
    automatic int unsigned bytes_per_beat = TbAxiDataWidth/8;

    // Initialize
    end_of_sim   = 1'b0;
    address_mapping_test_active = 1'b0;
    error_count  = 0;
    write_count  = 0;
    read_count   = 0;
    total_write_cycles = 0;
    total_read_cycles  = 0;

    // Reset drivers
    axi_drv.reset_master();
    axi_rand.reset();
    scoreboard.reset();

    // Configure random master memory region
    axi_rand.add_memory_region(TbMemBaseAddr, TbMemBaseAddr + TbMemSize - 1,
                               axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);

    // Enable scoreboard checks
    scoreboard.enable_all_checks();

    // Wait for reset
    @(posedge rst_n);
    repeat (10) @(posedge clk);

    // Start scoreboard monitoring
    scoreboard.monitor();

    $display("=========================================");
    $display("=  AXI to RegIF v2 Testbench Starting  =");
    $display("=========================================");
    $display("AXI Data Width:  %0d bits", TbAxiDataWidth);
    $display("Reg Data Width:  %0d bits", TbRegDataWidth);
    $display("Memory Size:     %0d bytes", TbMemSize);
    $display("AXI Size (log2): %0d", full_size);
    $display("=========================================\n");

    //////////////////////////////////////////////
    // Test 1: Address mapping
    //////////////////////////////////////////////
    $display("[TEST 1] Address mapping (32 full-width transactions)");
    test_start_time = current_cycle;
    address_mapping_test_active = 1'b1;

    // Write distinct data to widely separated, AXI-width-aligned addresses.
    for (int i = 0; i < 32; i++) begin
      test_addr = TbMemBaseAddr + (i * 'h100);
      axi_single_write(axi_drv, test_addr, address_mapping_data(i), full_size);
    end

    // Read after all writes so address aliases and misrouted accesses are detected.
    for (int i = 0; i < 32; i++) begin
      automatic axi_data_t rdata;
      automatic axi_data_t expected = address_mapping_data(i);
      test_addr = TbMemBaseAddr + (i * 'h100);
      axi_single_read(axi_drv, test_addr, full_size, rdata);
      if (rdata !== expected) begin
        $error("[TEST 1] Mismatch at address 0x%h: expected 0x%h, got 0x%h",
               test_addr, expected, rdata);
        error_count++;
      end
    end
    address_mapping_test_active = 1'b0;

    test_end_time = current_cycle;
    $display("[TEST 1] Completed: %0d cycles for 64 accesses", test_end_time - test_start_time);
    $display("");

    //////////////////////////////////////////////
    // Test 2: Random transactions via rand_master
    //////////////////////////////////////////////
    $display("[TEST 2] Random AXI transactions (via rand_master)");
    $display("         NOTE: rand_master uses bursts which may not be fully supported");
    $display("         Writes: %0d, Reads: %0d", TbNumWrites, TbNumReads);
    test_start_time = current_cycle;

    axi_rand.run(TbNumReads, TbNumWrites);

    test_end_time = current_cycle;
    throughput = real'(TbNumReads + TbNumWrites) / real'(test_end_time - test_start_time);
    $display("[TEST 2] Completed: %0d cycles for %0d transactions",
             test_end_time - test_start_time, TbNumReads + TbNumWrites);
    $display("         Throughput: %.2f transactions/cycle", throughput);
    $display("");

    //////////////////////////////////////////////
    // Test 3: Throughput - rapid single writes (full AXI width)
    //////////////////////////////////////////////
    $display("[TEST 3] Throughput - 1000 rapid single writes (full AXI width)");
    test_start_time = current_cycle;

    for (int i = 0; i < 1000; i++) begin
      test_addr = TbMemBaseAddr + 'h1000 + (i * bytes_per_beat);
      axi_single_write(axi_drv, test_addr, {TbAxiDataWidth/32{32'hCAFE_0000 + i}}, full_size);
    end

    test_end_time = current_cycle;
    throughput = real'(1000) / real'(test_end_time - test_start_time);
    $display("[TEST 3] Completed: %0d cycles for 1000 writes", test_end_time - test_start_time);
    $display("         Write throughput: %.2f transactions/cycle", throughput);
    $display("");

    //////////////////////////////////////////////
    // Test 4: Throughput - rapid single reads and verify (full AXI width)
    //////////////////////////////////////////////
    $display("[TEST 4] Throughput - 1000 rapid single reads with verification (full AXI width)");
    test_start_time = current_cycle;

    for (int i = 0; i < 1000; i++) begin
      automatic axi_data_t rdata;
      automatic axi_data_t expected = {TbAxiDataWidth/32{32'hCAFE_0000 + i}};
      test_addr = TbMemBaseAddr + 'h1000 + (i * bytes_per_beat);
      axi_single_read(axi_drv, test_addr, full_size, rdata);
      if (rdata !== expected) begin
        $error("[TEST 4] Mismatch at addr 0x%h: expected 0x%h, got 0x%h",
               test_addr, expected, rdata);
        error_count++;
      end
    end

    test_end_time = current_cycle;
    throughput = real'(1000) / real'(test_end_time - test_start_time);
    $display("[TEST 4] Completed: %0d cycles for 1000 reads", test_end_time - test_start_time);
    $display("         Read throughput: %.2f transactions/cycle", throughput);
    $display("");

    //////////////////////////////////////////////
    // Test 5: Throughput - burst writes and reads
    //////////////////////////////////////////////
    begin
      automatic int unsigned num_bursts = 100;
      automatic int unsigned burst_len = 15;  // 16 beats per burst (len+1)
      automatic int unsigned total_beats = num_bursts * (burst_len + 1);
      automatic int unsigned bytes_per_beat = TbAxiDataWidth / 8;
      automatic int unsigned burst_size_bytes = (burst_len + 1) * bytes_per_beat;
      automatic logic [2:0]  axi_size = $clog2(TbAxiDataWidth / 8);  // Full bus width

      $display("[TEST 5] Throughput - burst writes (%0d bursts x %0d beats)",
               num_bursts, burst_len + 1);
      test_start_time = current_cycle;

      for (int i = 0; i < num_bursts; i++) begin
        test_addr = TbMemBaseAddr + 'h5000 + (i * burst_size_bytes);
        axi_burst_write(axi_drv, test_addr, burst_len, axi_size);
      end

      test_end_time = current_cycle;
      throughput = real'(total_beats) / real'(test_end_time - test_start_time);
      $display("[TEST 5] Write phase: %0d cycles for %0d beats",
               test_end_time - test_start_time, total_beats);
      $display("         Burst write throughput: %.2f beats/cycle", throughput);

      $display("[TEST 5] Throughput - burst reads (%0d bursts x %0d beats)",
               num_bursts, burst_len + 1);
      test_start_time = current_cycle;

      for (int i = 0; i < num_bursts; i++) begin
        test_addr = TbMemBaseAddr + 'h5000 + (i * burst_size_bytes);
        axi_burst_read(axi_drv, test_addr, burst_len, axi_size);
      end

      test_end_time = current_cycle;
      throughput = real'(total_beats) / real'(test_end_time - test_start_time);
      $display("[TEST 5] Read phase: %0d cycles for %0d beats",
               test_end_time - test_start_time, total_beats);
      $display("         Burst read throughput: %.2f beats/cycle", throughput);
      $display("");
    end

    //////////////////////////////////////////////
    // Summary
    //////////////////////////////////////////////
    repeat (20) @(posedge clk);

    $display("=========================================");
    $display("=           Test Summary               =");
    $display("=========================================");
    if (error_count == 0) begin
      $display("ALL TESTS PASSED!");
    end else begin
      $display("TESTS FAILED with %0d errors!", error_count);
    end
    $display("=========================================");

    end_of_sim = 1'b1;
    repeat (10) @(posedge clk);
    $finish();
  end

endmodule
