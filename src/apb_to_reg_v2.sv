// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Philippe Sauter <phsauter@iis.ee.ethz.ch>
// Florian Zaruba  <zarubaf@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

/// Version 2 of a protocol converter from APB to the register interface.
module apb_to_reg_v2 #(
  /// Use combinational feedthrough, no latched request as the APB spec intends
  parameter bit Feedthrough = 1'b1,
  /// Regbus request struct type.
  parameter type         reg_req_t    = logic,
  /// Regbus response struct type.
  parameter type         reg_rsp_t    = logic
)(
  input  logic          clk_i,
  input  logic          rst_ni,

  input  logic          penable_i,
  input  logic          pwrite_i,
  input  logic [31:0]   paddr_i,
  input  logic          psel_i,
  input  logic [31:0]   pwdata_i,
  output logic [31:0]   prdata_o,
  output logic          pready_o,
  output logic          pslverr_o,

  output reg_req_t      reg_req_o,
  input  reg_rsp_t      reg_rsp_i
);

  if (Feedthrough) begin : gen_feedthrough
    // in this mode just using plain register interface makes more sense
    always_comb begin
      reg_req_o.addr = paddr_i;
      reg_req_o.write = pwrite_i;
      reg_req_o.wdata = pwdata_i;
      reg_req_o.wstrb = '1;
      pready_o        = reg_rsp_i.ready;
      pslverr_o       = reg_rsp_i.error;
      prdata_o        = reg_rsp_i.rdata;
    end

  end else begin : gen_apb_reg
    // latch forward path as apb intends
    `FF(reg_req_o.addr,  paddr_i,  '0, clk_i, rst_ni)
    `FF(reg_req_o.write, pwrite_i, '0, clk_i, rst_ni)
    `FF(reg_req_o.wdata, pwdata_i, '0, clk_i, rst_ni)

    always_comb begin
      reg_req_o.wstrb = '1;
      reg_req_o.valid = psel_i & penable_i;
      pready_o        = reg_rsp_i.ready;
      pslverr_o       = reg_rsp_i.error;
      prdata_o        = reg_rsp_i.rdata;
    end
  end
endmodule

module apb_to_reg_intf #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 32
)(
  APB.Slave    apb_i,
  REG_BUS.out  reg_o
);

  always_comb begin
    reg_o.addr    = apb_i.paddr;
    reg_o.write   = apb_i.pwrite;
    reg_o.wdata   = apb_i.pwdata;
    reg_o.wstrb   = '1;
    reg_o.valid   = apb_i.psel & apb_i.penable;
    apb_i.pready  = reg_o.ready;
    apb_i.pslverr = reg_o.error;
    apb_i.prdata  = reg_o.rdata;
  end

endmodule
