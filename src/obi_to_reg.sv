// Copyright 2025 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/**
 * Translates OBI to register_interface,
 * ignores the r_optional and a_optional fields
 */
module obi_to_reg #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ID_WIDTH   = 0,

  parameter type         obi_req_t = logic,
  parameter type         obi_rsp_t = logic,

  parameter type         reg_req_t = logic,
  parameter type         reg_rsp_t = logic
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o, 

  output reg_req_t reg_req_o,
  input  reg_rsp_t reg_rsp_i
);
  logic req_q, req_d;
  logic [ID_WIDTH-1:0] aid_q, aid_d;
  logic [DATA_WIDTH-1:0] rdata_q, rdata_d;
  logic error_q, error_d;

  assign req_d   = obi_req_i.req;
  assign aid_d   = obi_req_i.a.aid;
  assign rdata_d = reg_rsp_i.rdata;
  assign error_d = reg_rsp_i.error;

  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_seq
    if (!rst_ni) begin
      req_q   <= '0;
      rdata_q <= '0;
      aid_q   <= '0;
      error_q <= '0;
    end else begin
      req_q   <= req_d;
      rdata_q <= rdata_d;
      aid_q   <= aid_d;
      error_q <= error_d;
    end
  end

  assign reg_req_o.valid = obi_req_i.req;
  assign reg_req_o.addr  = obi_req_i.a.addr;
  assign reg_req_o.write = obi_req_i.a.we;
  assign reg_req_o.wdata = obi_req_i.a.wdata;
  assign reg_req_o.wstrb = obi_req_i.a.be;

  assign obi_rsp_o.gnt     = obi_req_i.req & reg_rsp_i.ready;
  assign obi_rsp_o.rvalid  = req_q;
  assign obi_rsp_o.r.rdata = rdata_q;
  assign obi_rsp_o.r.rid   = aid_q;
  assign obi_rsp_o.r.err   = error_q;
endmodule
