// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package test_regs_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 4;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    logic [31:0] q;
  } test_regs_reg2hw_reg1_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } test_regs_reg2hw_reg2_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } test_regs_reg2hw_reg3_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } test_regs_hw2reg_reg1_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } test_regs_hw2reg_reg2_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } test_regs_hw2reg_reg3_reg_t;

  // Register -> HW type
  typedef struct packed {
    test_regs_reg2hw_reg1_reg_t reg1; // [95:64]
    test_regs_reg2hw_reg2_reg_t reg2; // [63:32]
    test_regs_reg2hw_reg3_reg_t reg3; // [31:0]
  } test_regs_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    test_regs_hw2reg_reg1_reg_t reg1; // [98:66]
    test_regs_hw2reg_reg2_reg_t reg2; // [65:33]
    test_regs_hw2reg_reg3_reg_t reg3; // [32:0]
  } test_regs_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] TEST_REGS_REG1_OFFSET = 4'h 0;
  parameter logic [BlockAw-1:0] TEST_REGS_REG2_OFFSET = 4'h 4;
  parameter logic [BlockAw-1:0] TEST_REGS_REG3_OFFSET = 4'h 8;

  // Register index
  typedef enum int {
    TEST_REGS_REG1,
    TEST_REGS_REG2,
    TEST_REGS_REG3
  } test_regs_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] TEST_REGS_PERMIT [3] = '{
    4'b 1111, // index[0] TEST_REGS_REG1
    4'b 1111, // index[1] TEST_REGS_REG2
    4'b 1111  // index[2] TEST_REGS_REG3
  };

endpackage

