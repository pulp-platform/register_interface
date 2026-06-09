// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register slice conforming to Comportibility guide.

`ifndef LOWRISC_PRIM_SUBREG
  `define LOWRISC_PRIM_SUBREG

module prim_subreg
  import prim_subreg_pkg::*;
#(
  parameter int            DW       = 32,
  parameter sw_access_e    SwAccess = SwAccessRW,
  parameter logic [DW-1:0] RESVAL   = '0    // reset value
) (
  input  wire           clk_i,
  input  wire           rst_ni,

  // From SW: valid for RW, WO, W1C, W1S, W0C, RC
  // In case of RC, Top connects Read Pulse to we
  input  logic          we,
  input  logic [DW-1:0] wd,

  // From HW: valid for HRW, HWO
  input  logic          de,
  input  logic [DW-1:0] d,

  // output to HW and Reg Read
  output logic          qe,
  output logic [DW-1:0] q,
  output logic [DW-1:0] qs
);

  logic          wr_en;
  logic [DW-1:0] wr_data;

  prim_subreg_arb #(
    .DW       ( DW       ),
    .SwAccess ( SwAccess )
  ) wr_en_data_arb (
    .we,
    .wd,
    .de,
    .d,
    .q,
    .wr_en,
    .wr_data
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      qe <= 1'b0;
    end else begin
      qe <= we;
    end
  end

  logic wr_en_buf;
  // zarubaf: Removed since we are not in a security critical domain.
  assign wr_en_buf = wr_en;
  // prim_buf #(
  //   .Width(1)
  // ) u_wr_en_buf (
  //   .in_i(wr_en),
  //   .out_o(wr_en_buf)
  // );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q <= RESVAL;
    end else if (wr_en_buf) begin
      q <= wr_data;
    end
  end

  logic [DW-1:0] q_buf;
  // zarubaf: Removed since we are not in a security critical domain.
  assign q_buf = q;
  // prim_buf #(
  //   .Width(DW)
  // ) u_q_buf (
  //   .in_i(q),
  //   .out_o(q_buf)
  // );

  assign qs = q_buf;

endmodule

`endif
