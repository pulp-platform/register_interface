// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

/**
 * Reg Interface to Tile-Link
 */

module reg_to_tlul #(
  parameter type req_t = logic,
  parameter type rsp_t = logic,
  parameter type tl_h2d_t = logic,
  parameter type tl_d2h_t = logic,
  //you should pass tlul_pkg::TL_A_USER_DEFAULT from the OpenTitan TLUL package
  parameter type tl_a_user_t  = logic,
  parameter type tl_a_op_e  = logic,
  parameter tl_a_user_t TL_A_USER_DEFAULT = '0,
  parameter tl_a_op_e PutFullData = '0,
  parameter tl_a_op_e Get = '0
) (
    // Clock/reset — required for the one-outstanding A-channel handshake (see GAP-A9 note below).
    input  logic    clk_i,
    input  logic    rst_ni,

    // TL-UL interface
    output tl_h2d_t tl_o,
    input  tl_d2h_t tl_i,

    // Register interface
    input  req_t reg_req_i,
    output rsp_t reg_rsp_o
);

  // ---------------------------------------------------------------------------------------------
  // SF-1 GAP-A9 fix — proper one-outstanding TL-UL host A-channel.
  //
  // The stock adapter was a fire-and-forget A-channel: `tl_o.a_valid = reg_req_i.valid` with the
  // reg-side completion derived from `d_valid` ONLY (`reg_rsp_o.ready = tl_i.d_valid`), never
  // consulting `tl_i.a_ready`. Because the reg-bus holds `valid` until the *response*, `a_valid`
  // stayed asserted AFTER the device accepted the Get on `a_ready` (which precedes `d_valid` by
  // >=1 cycle on tlul_adapter_reg), so the device launched a DUPLICATE Get. Under a back-to-back
  // Get stream — e.g. axi_to_reg_v2 with NumBanks=2 on a 64b-AXI / 32b-reg bridge issues two Gets
  // per AXI read — the extra in-flight response desynchronises the D-channel and every other read
  // returns the previous/sibling value (stale). Verified on SF-1 via a core-held tb_axi tap.
  //
  // Fix: track exactly ONE outstanding transaction. `a_valid` is suppressed while a request is
  // accepted-but-unanswered, so the request retires on `a_ready` (acceptance) and is not re-issued
  // while its response is in flight. Cost: +0 latency, one flop. Backwards-compatible for a single
  // isolated access (NumBanks=1); only removes the spurious duplicate under pipelined Gets.
  // Upstream PR: https://github.com/pulp-platform/register_interface/pull/<NN> (see patches/).
  // ---------------------------------------------------------------------------------------------
  logic outstanding_q;
  logic a_ack, d_ack;
  assign a_ack = tl_o.a_valid & tl_i.a_ready;   // device accepted the A-channel request
  assign d_ack = tl_i.d_valid & tl_o.d_ready;   // response consumed this cycle

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)               outstanding_q <= 1'b0;
    else if ( a_ack & !d_ack)  outstanding_q <= 1'b1;   // accepted, awaiting its response
    else if (!a_ack &  d_ack)  outstanding_q <= 1'b0;   // response done, free to issue again
    // a_ack & d_ack in the same cycle (latency-0 device): issue+retire, net unchanged.
  end

  assign tl_o.a_valid    = reg_req_i.valid & ~outstanding_q;  // one outstanding; deassert on accept
  assign tl_o.a_opcode   = reg_req_i.write ? PutFullData : Get;
  assign tl_o.a_param    = '0;
  assign tl_o.a_size     = 'h2;
  assign tl_o.a_source   = '0;
  assign tl_o.a_address  = reg_req_i.addr;
  assign tl_o.a_mask     = reg_req_i.wstrb;
  assign tl_o.a_data     = reg_req_i.wdata;
  assign tl_o.a_user     = TL_A_USER_DEFAULT;
  assign tl_o.d_ready    = 1'b1;

  assign reg_rsp_o.ready = tl_i.d_valid & tl_o.d_ready;
  assign reg_rsp_o.rdata = tl_i.d_data;
  assign reg_rsp_o.error = tl_i.d_error;


endmodule
