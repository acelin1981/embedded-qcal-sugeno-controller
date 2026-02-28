// SPDX-License-Identifier: MIT
//
// MIT License
//
// Copyright (c) 2026 Che-Ping Lin (Ace Lin)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// ============================================================
// Module: qcal_apb
// Description: APB-lite register interface for control/status, rule table programming/readback, and telemetry readout (no wait states).
// ============================================================
`timescale 1ns/1ps
// NOTE (iverilog): To maximize compatibility with Icarus Verilog, avoid
// package-qualified types in the *port list*. We keep the fixed-point format
// (Q4.12 signed 16-bit) but express it as a plain packed vector type.
module qcal_apb #(
  parameter int APB_ADDR_W = 12
)(
  input  logic clk,
  input  logic rst_n,
  input  logic PSEL,
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [APB_ADDR_W-1:0] PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA,
  output logic PREADY,
  output logic PSLVERR,

  output logic mode_sel,
  output logic start_pulse,
  output logic rule_wr_pulse,
  output logic [3:0] rule_addr,
  output logic signed [15:0]  rule_delta,

  // rule readback controls
  output logic [3:0] rule_rd_addr,
  input  logic signed [15:0]  rule_rd_delta,

  input  logic busy,
  input  logic converged,
  input  logic oscillating,
  input  logic signed [15:0]  reg_amp_out,
  input  logic signed [15:0]  last_e,
  input  logic signed [15:0]  last_delta,
  input  logic signed [15:0]  last_de,
  input  logic signed [15:0]  last_p_meas,
  input  logic [31:0] update_cnt
);
  // Fixed-point config (matches qcal_pkg)
  localparam int FP_W = 16;
  localparam int FP_F = 12;
  typedef logic signed [FP_W-1:0] fp_t;

  function automatic logic [31:0] sx16_to32(input fp_t x);
    sx16_to32 = {{16{x[FP_W-1]}}, x};
  endfunction
  localparam int A_CTRL        = 12'h000;
  localparam int A_RULE_ADDR   = 12'h010;
  localparam int A_RULE_DATA   = 12'h014;
  localparam int A_RULE_WR     = 12'h018;
  localparam int A_STATUS      = 12'h020;
  localparam int A_AMP         = 12'h024;
  localparam int A_LAST_E      = 12'h028;
  localparam int A_LAST_D      = 12'h02C;
  localparam int A_UPD_CNT     = 12'h030;
  localparam int A_RULE_RDADDR = 12'h034;
  localparam int A_RULE_RDDATA = 12'h038;
  localparam int A_LAST_DE     = 12'h03C;
  localparam int A_LAST_PMEAS  = 12'h040;

  logic [31:0] ctrl_r;
  logic [3:0]  rule_addr_r;
  fp_t rule_delta_r;
  logic [3:0]  rule_rd_addr_r;

  assign PREADY = 1'b1; // no wait states

  wire apb_wr = PSEL & PENABLE & PWRITE;
  wire apb_rd = PSEL & ~PWRITE;

  function automatic bit is_mapped(input logic [APB_ADDR_W-1:0] a);
    case (a)
      A_CTRL, A_RULE_ADDR, A_RULE_DATA, A_RULE_WR,
      A_STATUS, A_AMP, A_LAST_E, A_LAST_D, A_UPD_CNT,
      A_RULE_RDADDR, A_RULE_RDDATA, A_LAST_DE, A_LAST_PMEAS: is_mapped = 1'b1;
      default: is_mapped = 1'b0;
    endcase
  endfunction

  // Icarus Verilog: prefer plain always @* over always_comb
  always @* begin
    if (PSEL && PENABLE && !is_mapped(PADDR)) PSLVERR = 1'b1;
    else PSLVERR = 1'b0;
  end

  // Icarus Verilog: prefer always @(...) over always_ff
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      ctrl_r <= 32'h0;
      rule_addr_r <= 4'd0;
      rule_delta_r <= '0;
      rule_rd_addr_r <= 4'd0;
      start_pulse <= 1'b0;
      rule_wr_pulse <= 1'b0;
    end else begin
      start_pulse <= 1'b0;
      rule_wr_pulse <= 1'b0;
      if (apb_wr && is_mapped(PADDR)) begin
        case (PADDR)
          A_CTRL: begin
            ctrl_r[0] <= PWDATA[0];
            if (PWDATA[1]) start_pulse <= 1'b1;
          end
          A_RULE_ADDR:   rule_addr_r <= PWDATA[3:0];
          A_RULE_DATA:   rule_delta_r <= fp_t'(PWDATA[15:0]);
          A_RULE_WR:     if (PWDATA[0]) rule_wr_pulse <= 1'b1;
          A_RULE_RDADDR: rule_rd_addr_r <= PWDATA[3:0];
          default: ;
        endcase
      end
    end
  end

  assign mode_sel    = ctrl_r[0];
  assign rule_addr   = rule_addr_r;
  assign rule_delta  = rule_delta_r;
  assign rule_rd_addr= rule_rd_addr_r;

  always @* begin
    PRDATA = 32'h0;
    if (apb_rd && is_mapped(PADDR)) begin
      case (PADDR)
        A_CTRL:        PRDATA = ctrl_r;
        A_RULE_ADDR:   PRDATA = {28'h0, rule_addr_r};
        A_RULE_DATA:   PRDATA = sx16_to32(rule_delta_r);
        A_RULE_WR:     PRDATA = 32'h0;
        A_STATUS:      PRDATA = {29'h0, oscillating, converged, busy};
        A_AMP:         PRDATA = sx16_to32(fp_t'(reg_amp_out));
        A_LAST_E:      PRDATA = sx16_to32(fp_t'(last_e));
        A_LAST_D:      PRDATA = sx16_to32(fp_t'(last_delta));
        A_UPD_CNT:     PRDATA = update_cnt;
        A_RULE_RDADDR: PRDATA = {28'h0, rule_rd_addr_r};
        A_RULE_RDDATA: PRDATA = sx16_to32(fp_t'(rule_rd_delta));
        A_LAST_DE:     PRDATA = sx16_to32(fp_t'(last_de));
        A_LAST_PMEAS:  PRDATA = sx16_to32(fp_t'(last_p_meas));
        default:       PRDATA = 32'h0;
      endcase
    end
  end
endmodule
