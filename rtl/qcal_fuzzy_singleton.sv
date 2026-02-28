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
// Module: qcal_fuzzy_singleton
// Description: Singleton Sugeno fuzzy inference: compute rule weights w_ij=mu_e(i)*mu_de(j), accumulate Σ(w·D) and Σw, then output Δ via normalization.
// ============================================================
`timescale 1ns/1ps

module qcal_fuzzy_singleton (
  input  logic clk, input logic rst_n,
  input  logic in_valid,
  input  logic signed [15:0]  e,
  input  logic signed [15:0]  de,

  // mode + manual table fill
  input  logic mode_sel,
  input  logic rule_manual_wr_en,
  input  logic [3:0] rule_manual_addr,
  input  logic signed [15:0]  rule_manual_delta,

  // debug readback (APB)
  input  logic [3:0] dbg_rule_rd_addr,
  output logic signed [15:0]  dbg_rule_rd_delta,

  output logic out_valid,
  output logic signed [15:0]  delta
);
  localparam int FP_W = 16;
  typedef logic signed [FP_W-1:0] fp_t;

  // Icarus Verilog compatibility:
  // Avoid declaring variables inside procedural blocks.
  logic [31:0] w32;
  logic [15:0] w16;

  logic [15:0] mu_e_n,mu_e_z,mu_e_p, mu_d_n,mu_d_z,mu_d_p;
  qcal_membership_tri #(.IN_W(FP_W)) u_me(.x(fp_t'(e)), .mu_neg(mu_e_n), .mu_zero(mu_e_z), .mu_pos(mu_e_p));
  qcal_membership_tri #(.IN_W(FP_W)) u_md(.x(fp_t'(de)),.mu_neg(mu_d_n), .mu_zero(mu_d_z), .mu_pos(mu_d_p));

  function automatic logic [15:0] mu_e(input int k);
    case(k) 0:mu_e=mu_e_n; 1:mu_e=mu_e_z; default:mu_e=mu_e_p; endcase
  endfunction
  function automatic logic [15:0] mu_d(input int k);
    case(k) 0:mu_d=mu_d_n; 1:mu_d=mu_d_z; default:mu_d=mu_d_p; endcase
  endfunction

  fp_t d_i; logic [3:0] idx;
  qcal_rule_mem_singleton u_tab(
    .clk(clk),.rst_n(rst_n),
    .manual_en(mode_sel),
    .manual_wr_en(rule_manual_wr_en),
    .manual_addr(rule_manual_addr),
    .manual_delta(rule_manual_delta),
    .rd0_addr(idx),
    .rd0_delta(d_i),
    .rd1_addr(dbg_rule_rd_addr),
    .rd1_delta(dbg_rule_rd_delta)
  );

  typedef enum logic [1:0] {S_IDLE,S_ACC,S_DIV,S_OUT} st_t;
  st_t st; int r,c;
  logic signed [31:0] num_acc;
  logic [31:0] den_acc;

  logic div_start,div_busy,div_done; logic [31:0] div_q;
  qcal_divider #(.W(32)) u_div(
    .clk(clk),.rst_n(rst_n),.start(div_start),
    .numerator($unsigned(num_acc >>> 16)),
    .denominator(den_acc),
    .busy(div_busy),.done(div_done),.quotient(div_q)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      st<=S_IDLE; r<=0; c<=0; idx<=0; num_acc<=0; den_acc<=0;
      div_start<=0; out_valid<=0; delta<='0;
    end else begin
      div_start<=0; out_valid<=0;
      // Use plain case for broad tool compatibility.
      case(st)
        S_IDLE: if(in_valid) begin r<=0; c<=0; idx<=0; num_acc<=0; den_acc<=0; st<=S_ACC; end
        S_ACC: begin
          idx <= r*3+c;
          w32 = mu_e(r) * mu_d(c);
          w16 = w32[31:16];
          num_acc <= num_acc + ($signed({1'b0,w16}) * $signed(d_i));
          den_acc <= den_acc + w16;
          if(c==2) begin c<=0; if(r==2) st<=S_DIV; else r<=r+1; end else c<=c+1;
        end
        S_DIV: begin
          if(den_acc==0) begin delta<='0; st<=S_OUT; end
          else begin
            if(!div_busy && !div_done) div_start<=1;
            if(div_done) begin delta <= fp_t'(div_q[FP_W-1:0]); st<=S_OUT; end
          end
        end
        S_OUT: begin out_valid<=1; st<=S_IDLE; end
      endcase
    end
  end
endmodule
