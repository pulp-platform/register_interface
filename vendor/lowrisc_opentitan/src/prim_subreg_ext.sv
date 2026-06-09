// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register slice conforming to Comportibility guide.

`ifndef LOWRISC_PRIM_SUBREG_EXT
  `define LOWRISC_PRIM_SUBREG_EXT

module prim_subreg_ext #(
  parameter int unsigned DW = 32
) (
  input  logic          re,
  input  logic          we,
  input  logic [DW-1:0] wd,

  input  logic [DW-1:0] d,

  // output to HW and Reg Read
  output logic          qe,
  output logic          qre,
  output logic [DW-1:0] q,
  output logic [DW-1:0] qs
);

  assign qs = d;
  assign q = wd;
  assign qe = we;
  assign qre = re;

endmodule

`endif
