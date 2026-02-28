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
// Module: qcal_supervisor_fsm
// Description: Top-level scheduler FSM: orchestrates measurement windows and parameter updates; transitions from CAL (update) mode to MON (monitor) mode.
// ============================================================
`timescale 1ns/1ps
module qcal_supervisor_fsm #(
  parameter int DEFAULT_NSHOTS = 256,
  parameter integer DBG = 1
)(
  input  logic clk,
  input  logic rst_n,
  input  logic start_pulse,
  input  logic converged,
  input  logic drift,
  input  logic seq_done,
  input  logic update_done,
  output logic seq_start,
  output logic [15:0] nshots,
  output logic busy
);
  // After a manual start, the supervisor runs continuously:
  //   - CAL mode (busy=1): run window -> update -> next
  //   - MON mode (busy=0): run window (no update) and watch for drift
  typedef enum logic [2:0] {IDLE, CAL_START, CAL_WAIT_SEQ, CAL_WAIT_UPD, MON_START, MON_WAIT_SEQ} st_t;
  st_t st;
  st_t st_prev;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= IDLE;
      st_prev <= IDLE;
      nshots <= DEFAULT_NSHOTS;
      seq_start <= 1'b0;
      busy <= 1'b0;
    end else begin
      seq_start <= 1'b0;
      // Icarus Verilog: use plain case (unique is ignored)
      case (st)
        IDLE: begin
          busy <= 1'b0;
          if (start_pulse) begin
            busy <= 1'b1;
            st   <= CAL_START;
          end
        end

        // -----------------
        // Calibration mode
        // -----------------
        CAL_START: begin
          busy     <= 1'b1;
          seq_start<= 1'b1;
          st       <= CAL_WAIT_SEQ;
        end
        CAL_WAIT_SEQ: begin
          busy <= 1'b1;
          if (seq_done) st <= CAL_WAIT_UPD;
        end
        CAL_WAIT_UPD: begin
          busy <= 1'b1;
          if (update_done) begin
            // When converged, drop busy and enter monitor mode.
            if (converged) begin
              busy <= 1'b0;
              st   <= MON_START;
            end else begin
              st   <= CAL_START;
            end
          end
        end

        // -----------------
        // Monitor mode
        // -----------------
        MON_START: begin
          busy      <= 1'b0;
          seq_start <= 1'b1;
          st        <= MON_WAIT_SEQ;
        end
        MON_WAIT_SEQ: begin
          busy <= 1'b0;
          if (seq_done) begin
            // Drift detected -> re-enter calibration automatically.
            if (drift) begin
              busy <= 1'b1;
              st   <= CAL_START;
            end else begin
              st   <= MON_START;
            end
          end
        end

        default: st <= IDLE;
      endcase
      if (DBG && st != st_prev) begin
        $display("[FSMDBG] t=%0t st=%0d->%0d start=%0d conv=%0d drift=%0d seq_done=%0d upd_done=%0d busy=%0d", $time, st_prev, st, start_pulse, converged, drift, seq_done, update_done, busy);
      end
      st_prev <= st;
    end
  end
endmodule
