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
// Module: qcal_apb_top
// Description: Top wrapper: ties APB interface to qcal_core and exposes plant_bit inputs for simulation/SoC integration.
// ============================================================
`timescale 1ns/1ps
module qcal_apb_top (
  input  logic clk,
  input  logic rst_n,
  input  logic PSEL,
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [11:0] PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA,
  output logic PREADY,
  output logic PSLVERR,
  input  logic plant_bit_valid,
  input  logic plant_bit
);
  // Fixed-point config (Q4.12 signed 16-bit, matches qcal_pkg)
  localparam int FP_W = 16;
  typedef logic signed [FP_W-1:0] fp_t;

  logic mode_sel, start_pulse, rule_wr_pulse;
  logic [3:0] rule_addr, rule_rd_addr;
  fp_t rule_delta, rule_rd_delta;

  fp_t reg_amp_out, last_e, last_delta;
  logic busy, converged, oscillating;
  logic [31:0] update_cnt;

  qcal_apb u_apb(
    .clk(clk),.rst_n(rst_n),
    .PSEL(PSEL),.PENABLE(PENABLE),.PWRITE(PWRITE),.PADDR(PADDR),.PWDATA(PWDATA),
    .PRDATA(PRDATA),.PREADY(PREADY),.PSLVERR(PSLVERR),
    .mode_sel(mode_sel),.start_pulse(start_pulse),
    .rule_wr_pulse(rule_wr_pulse),.rule_addr(rule_addr),.rule_delta(rule_delta),
    .rule_rd_addr(rule_rd_addr),.rule_rd_delta(rule_rd_delta),
    .busy(busy),.converged(converged),.oscillating(oscillating),
    .reg_amp_out(reg_amp_out),.last_e(last_e),.last_delta(last_delta),
    .update_cnt(update_cnt)
  );

  qcal_core u_core(
    .clk(clk),.rst_n(rst_n),
    .mode_sel(mode_sel),
    .start_pulse(start_pulse),
    .rule_manual_wr_en(rule_wr_pulse & mode_sel),
    .rule_manual_addr(rule_addr),
    .rule_manual_delta(rule_delta),
    .dbg_rule_rd_addr(rule_rd_addr),
    .dbg_rule_rd_delta(rule_rd_delta),
    .plant_bit_valid(plant_bit_valid),
    .plant_bit(plant_bit),
    .reg_amp_out(reg_amp_out),
    .last_e(last_e),
    .last_delta(last_delta),
    .converged(converged),
    .oscillating(oscillating),
    .busy(busy),
    .update_cnt(update_cnt)
  );
endmodule
