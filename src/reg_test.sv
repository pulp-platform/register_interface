// Copyright (C) 2017-2018 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

timeunit 1ns/1ps;

/// A set of testbench utilities for AXI interfaces.
package reg_test;

  /// A driver for AXI4-Lite interface.
  class reg_driver #(
    parameter int  AW       ,
    parameter int  DW       ,
    parameter time TA = 0ns , // stimuli application time
    parameter time TT = 0ns   // stimuli test time
  );
    virtual REG_BUS #(
      .ADDR_WIDTH(AW),
      .DATA_WIDTH(DW)
    ) bus;

    function new(
      virtual REG_BUS #(
        .ADDR_WIDTH(AW),
        .DATA_WIDTH(DW)
      ) bus
    );
      this.bus = bus;
    endfunction

    task reset_master;
      bus.addr  <= '0;
      bus.write <= '0;
      bus.wdata <= '0;
      bus.wstrb <= '0;
      bus.valid <= '0;
    endtask

    task reset_slave;
      bus.rdata <= '0;
      bus.error <= '0;
      bus.ready <= '0;
    endtask

    task cycle_start;
      #TT;
    endtask

    task cycle_end;
      @(posedge bus.clk_i);
    endtask

    /// Issue a write transaction.
    task send_write (
      input  logic [AW-1:0] addr,
      input  logic [DW-1:0] data,
      input  logic [DW/8-1:0] strb,
      output logic error
    );
      bus.addr  <= #TA addr;
      bus.write <= #TA 1;
      bus.wdata <= #TA data;
      bus.wstrb <= #TA strb;
      bus.valid <= #TA 1;
      cycle_start();
      while (bus.ready != 1) begin cycle_end(); cycle_start(); end
      error = bus.error;
      cycle_end();
      bus.addr  <= #TA '0;
      bus.write <= #TA 0;
      bus.wdata <= #TA '0;
      bus.wstrb <= #TA '0;
      bus.valid <= #TA 0;
    endtask

    /// Issue a read transaction.
    task send_read (
      input  logic [AW-1:0] addr,
      output logic [DW-1:0] data,
      output logic error
    );
      bus.addr  <= #TA addr;
      bus.write <= #TA 0;
      bus.valid <= #TA 1;
      cycle_start();
      while (bus.ready != 1) begin cycle_end(); cycle_start(); end
      data  = bus.rdata;
      error = bus.error;
      cycle_end();
      bus.addr  <= #TA '0;
      bus.write <= #TA 0;
      bus.valid <= #TA 0;
    endtask

  endclass

endpackage
