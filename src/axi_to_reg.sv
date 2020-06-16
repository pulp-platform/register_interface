// Copyright 2018-2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

/// A protocol converter from AXI4 to a register interface.
module axi_to_reg #(
  /// The width of the address.
  parameter int ADDR_WIDTH = -1,
  /// The width of the data.
  parameter int DATA_WIDTH = -1,
  /// The width of the id.
  parameter int ID_WIDTH = -1,
  /// The width of the user signal.
  parameter int USER_WIDTH = -1,
  /// Whether the AXI-Lite W channel should be decoupled with a register. This
  /// can help break long paths at the expense of registers.
  parameter bit DECOUPLE_W = 1
)(
  input  logic  clk_i     ,
  input  logic  rst_ni    ,
  input  logic  testmode_i,
  AXI_BUS.Slave in        ,
  REG_BUS.out   reg_o
);

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( ADDR_WIDTH ),
    .AXI_DATA_WIDTH ( DATA_WIDTH )
  ) axi_lite ();

  //  convert axi to axi-lite
  axi_to_axi_lite_intf #(
    .AXI_ADDR_WIDTH     ( ADDR_WIDTH ),
    .AXI_DATA_WIDTH     ( DATA_WIDTH ),
    .AXI_ID_WIDTH       ( ID_WIDTH   ),
    .AXI_USER_WIDTH     ( USER_WIDTH ),
    /// Maximum number of outstanding writes.
    .AXI_MAX_WRITE_TXNS ( 2 ),
    /// Maximum number of outstanding reads.
    .AXI_MAX_READ_TXNS  ( 2 ),
    .FALL_THROUGH       ( 0 )
  ) i_axi_to_axi_lite (
    .clk_i,
    .rst_ni,
    .testmode_i,
    .slv ( in ),
    .mst ( axi_lite )
  );

  axi_lite_to_reg #(
    /// The width of the address.
    .ADDR_WIDTH ( ADDR_WIDTH ),
    /// The width of the data.
    .DATA_WIDTH ( DATA_WIDTH ),
    /// Whether the AXI-Lite W channel should be decoupled with a register. This
    /// can help break long paths at the expense of registers.
    .DECOUPLE_W ( DECOUPLE_W )
  ) i_axi_lite_to_reg (
    .clk_i,
    .rst_ni,
    .axi_i ( axi_lite ),
    .reg_o
  );

endmodule
