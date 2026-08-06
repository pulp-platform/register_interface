// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Philippe Sauter <phsauter@iis.ee.ethz.ch>

/// A simple memory model that uses the register interface protocol.
/// This module acts as a memory sink for testing purposes.
/// It stores data on writes and returns stored data on reads.
/// Uses combinational read output as required by periph_to_reg:
/// - ready is asserted same cycle as valid
/// - rdata must be valid when ready is asserted
module reg_test_mem #(
  /// Address width
  parameter int unsigned AddrWidth = 32,
  /// Data width
  parameter int unsigned DataWidth = 32,
  /// Request struct type
  parameter type         req_t     = logic,
  /// Response struct type
  parameter type         rsp_t     = logic,
  /// Memory size in bytes (defaults to 4KB)
  parameter int unsigned MemSize   = 4096,
  /// Base address of the memory
  parameter logic [AddrWidth-1:0] BaseAddr = '0
)(
  input  logic clk_i,
  input  logic rst_ni,
  input  req_t reg_req_i,
  output rsp_t reg_rsp_o
);

  // Calculate the number of bytes per data word
  localparam int unsigned StrbWidth = DataWidth / 8;
  // Number of words in memory
  localparam int unsigned NumWords = MemSize / StrbWidth;
  // Calculate address width needed for memory indexing
  localparam int unsigned MemAddrWidth = $clog2(NumWords);

  // Memory storage
  logic [DataWidth-1:0] memory [NumWords];

  // Address offset calculation
  logic [AddrWidth-1:0] addr_offset;
  assign addr_offset = reg_req_i.addr - BaseAddr;

  // Word-aligned address for memory indexing
  logic [MemAddrWidth-1:0] word_addr;
  assign word_addr = addr_offset[$clog2(StrbWidth) +: MemAddrWidth];

  // Check if address is in range
  logic addr_in_range;
  assign addr_in_range = (reg_req_i.addr >= BaseAddr) &&
                          (addr_offset < MemSize);

  // Write logic (sequential)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Initialize memory with zeros
      for (int i = 0; i < NumWords; i++) begin
        memory[i] <= '0;
      end
    end else begin
      if (reg_req_i.valid && reg_req_i.write && addr_in_range) begin
        // Write operation with byte strobes
        for (int i = 0; i < StrbWidth; i++) begin
          if (reg_req_i.wstrb[i]) begin
            memory[word_addr][i*8 +: 8] <= reg_req_i.wdata[i*8 +: 8];
          end
        end
      end
    end
  end

  // Output assignments - COMBINATIONAL read path
  // periph_to_reg expects rdata to be valid when ready is asserted
  assign reg_rsp_o.rdata = addr_in_range ? memory[word_addr] : '0;
  assign reg_rsp_o.error = reg_req_i.valid && !addr_in_range;
  assign reg_rsp_o.ready = 1'b1; // Always ready

  // Assertions for debugging
`ifndef SYNTHESIS
  initial begin
    assert (DataWidth % 8 == 0) else $fatal(1, "DataWidth must be a multiple of 8!");
    assert (MemSize > 0) else $fatal(1, "MemSize must be greater than 0!");
    assert (MemSize % StrbWidth == 0) else $fatal(1, "MemSize must be a multiple of word size!");
  end
`endif

endmodule
