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
// Module: qcal_core
// Description: Controller core integrating supervisor, measurement path, error estimator, fuzzy inference, parameter update, and monitors; exposes telemetry.
// ============================================================
`timescale 1ns/1ps
module qcal_core #(
  // Expose tuning knobs at instance level (so APB top or SoC can override)
  parameter logic signed [15:0] AMP_STEP_LIMIT = 16'sd512,
  parameter logic signed [15:0] AMP_SAT_MIN    = -16'sd16384, // -4.0 (Q4.12)
  parameter logic signed [15:0] AMP_SAT_MAX    =  16'sd16384  // +4.0 (Q4.12)
)(
  input  logic clk, input logic rst_n,
  input  logic mode_sel,
  input  logic start_pulse,
  input  logic rule_manual_wr_en,
  input  logic [3:0] rule_manual_addr,
  input  logic signed [15:0]  rule_manual_delta,

  // debug rule readback
  input  logic [3:0] dbg_rule_rd_addr,
  output logic signed [15:0]  dbg_rule_rd_delta,

  input  logic plant_bit_valid, input logic plant_bit,
  output logic signed [15:0] reg_amp_out,
  output logic signed [15:0] last_e,
  output logic signed [15:0] last_delta,
  output logic converged,
  output logic oscillating,
  output logic busy,
  output logic [31:0] update_cnt
);
  // Fixed-point config (Q4.12 signed 16-bit)
  localparam int FP_W = 16;
  localparam int FP_F = 12;
  typedef logic signed [FP_W-1:0] fp_t;
  logic seq_start, seq_done, update_done;
  logic [15:0] nshots;
  logic drift;
  fp_t abs_e_avg;
  logic cal_busy;

  qcal_supervisor_fsm #(.DBG(1)) u_sup(
    .clk(clk),.rst_n(rst_n),
    .start_pulse(start_pulse),
    .converged(converged),
    .drift(drift),
    .seq_done(seq_done),
    .update_done(update_done),
    .seq_start(seq_start),
    .nshots(nshots),
    .busy(cal_busy)
  );

  // Export busy to APB/status
  assign busy = cal_busy;

  fp_t reg_amp; logic rf_wr_en; fp_t rf_wr_data;
  qcal_regfile u_rf(.clk(clk),.rst_n(rst_n),.wr_en(rf_wr_en),.wr_data(rf_wr_data),.reg_amp(reg_amp));
  assign reg_amp_out = reg_amp;

  logic win_active, shot_tick, win_done;
  qcal_pulse_sequencer_stub u_seq(.clk(clk),.rst_n(rst_n),.seq_start(seq_start),.nshots(nshots),
                                  .win_active(win_active),.shot_tick(shot_tick),.win_done(win_done));
  assign seq_done = win_done;

  logic meas_valid, meas_bit;
  qcal_discriminator_stub u_disc(.clk(clk),.rst_n(rst_n),.shot_tick(shot_tick),
                                 .plant_bit_valid(plant_bit_valid),.plant_bit(plant_bit),
                                 .meas_valid(meas_valid),.meas_bit(meas_bit));

  logic [15:0] count1,N_total; logic stats_valid;
  qcal_meas_stats #(.DBG(1)) u_stats(.clk(clk),.rst_n(rst_n),.win_active(win_active),
                          .meas_valid(meas_valid),.meas_bit(meas_bit),
                          .count1(count1),.N_total(N_total),.stats_valid(stats_valid));

  // 0.5 in Q4.12 = 0.5 * 2^12 = 2048 = 0x0800
  fp_t p_target; initial p_target = fp_t'(16'sh0800);
  logic est_valid; fp_t p_meas,e,de;
  qcal_error_estimator #(.DBG(1)) u_est(.clk(clk),.rst_n(rst_n),.stats_valid(stats_valid),
                             .count1(count1),.N_total(N_total),.p_target(p_target),
                             .out_valid(est_valid),.p_meas(p_meas),.e(e),.de(de));

  logic ctrl_valid; fp_t delta;
  qcal_fuzzy_singleton u_ctrl(.clk(clk),.rst_n(rst_n),.in_valid(est_valid),
                              .e(e),.de(de),
                              .mode_sel(mode_sel),
                              .rule_manual_wr_en(rule_manual_wr_en),
                              .rule_manual_addr(rule_manual_addr),
                              .rule_manual_delta(rule_manual_delta),
                              .dbg_rule_rd_addr(dbg_rule_rd_addr),
                              .dbg_rule_rd_delta(dbg_rule_rd_delta),
                              .out_valid(ctrl_valid),.delta(delta));

  // Only update parameter in CAL mode. In MON mode we still measure/estimate
  // and update convergence/drift monitors, but keep amp frozen.
  logic ctrl_valid_cal;
  assign ctrl_valid_cal = ctrl_valid & cal_busy;

  logic upd_valid; fp_t amp_next;
  qcal_param_update #(
    .STEP_LIMIT(AMP_STEP_LIMIT),
    .SAT_MIN(AMP_SAT_MIN),
    .SAT_MAX(AMP_SAT_MAX)
  ) u_upd(
    .clk(clk),.rst_n(rst_n),
    .in_valid(ctrl_valid_cal),
    .cur_param(reg_amp),.delta(delta),
    .out_valid(upd_valid),.next_param(amp_next)
  );

  qcal_convergence_monitor #(.DBG(1)) u_mon(
    .clk(clk),.rst_n(rst_n),
    .sample_valid(est_valid),
    .e(e),
    .converged(converged),
    .oscillating(oscillating),
    .drift(drift),
    .abs_e_avg_o(abs_e_avg)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin last_e<='0; last_delta<='0; update_cnt<=32'd0; end
    else begin
      if(ctrl_valid) begin last_e<=e; last_delta<=delta; $display("[COREDBG] t=%0t ctrl_valid e=%f de=%f delta=%f", $time, $itor($signed(e))/4096.0, $itor($signed(de))/4096.0, $itor($signed(delta))/4096.0); end
      if(upd_valid) begin update_cnt <= update_cnt + 1; $display("[COREDBG] t=%0t upd_valid amp_next=%f upd_cnt->%0d", $time, $itor($signed(amp_next))/4096.0, update_cnt+1); end
    end
  end

  always_comb begin
    rf_wr_en = upd_valid;
    rf_wr_data = amp_next;
    update_done = upd_valid;
  end
endmodule
