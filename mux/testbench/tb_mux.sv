`timescale 1ns/1ps

`include "uvm_macros.svh"

import uvm_pkg::*;

interface mux_if ();
  logic [3:0] a;
  logic [3:0] b;
  logic [3:0] c;
  logic [3:0] d;

  logic [1:0] sel;

  logic [3:0] y;

endinterface

class transaction extends uvm_sequence_item;
  
    rand bit [3:0] a;
    rand bit [3:0] b;
    rand bit [3:0] c;
    rand bit [3:0] d;
    rand bit [1:0] sel;
    bit [3:0] y;

    function new(input string path = "transaction");
        super.new(path);
    endfunction

    `uvm_object_utils_begin(transaction)
        `uvm_field_int(a, UVM_DEFAULT);
        `uvm_field_int(b, UVM_DEFAULT);
        `uvm_field_int(c, UVM_DEFAULT);
        `uvm_field_int(d, UVM_DEFAULT);
        `uvm_field_int(sel, UVM_DEFAULT);
        `uvm_field_int(y, UVM_DEFAULT);
    `uvm_object_utils_end

endclass

class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)

    transaction gen_transc;

    function new(input string path = "generator");
        super.new(path);
    endfunction

    virtual task body();
      	gen_transc = transaction::type_id::create("gen_transc");

        repeat(10) begin
            start_item(gen_transc);
            gen_transc.randomize();
            `uvm_info("GEN", $sformatf("Data Generated: a = %0d, b = %0d, \
            c = %0d, d = %0d, sel = %0d",gen_transc.a, gen_transc.b, 
            gen_transc.c, gen_transc.d, gen_transc.sel), UVM_LOW);
            finish_item(gen_transc);
        end
    endtask
endclass

class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver);

    transaction drv_transc;

    virtual mux_if drv_mif;

    function new(input string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_transc = transaction::type_id::create("drv_transc", this);

      	if (!uvm_config_db #(virtual mux_if)::get(this, "", "mif", drv_mif)) begin 
            `uvm_error("DRV", "config_db get failed: Unable to access config_bd.");
        end
        else begin 
            `uvm_info("DRV", "config_db get successful.", UVM_LOW);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(drv_transc);
            drv_mif.a = drv_transc.a;
            drv_mif.b = drv_transc.b;
            drv_mif.c = drv_transc.c;
            drv_mif.d = drv_transc.d;
            drv_mif.sel = drv_transc.sel;
            `uvm_info("DRV", $sformatf("Data Sent: a = %0d, b = %0d \
            c = %0d, d = %0d, sel = %0d", drv_transc.a, drv_transc.b, 
            drv_transc.c, drv_transc.d, drv_transc.sel), UVM_LOW);
            seq_item_port.item_done();
            #10;
        end
    endtask

endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) send;

    transaction mon_transc;

    virtual mux_if mon_mif;

    function new(input string path = "monitor", uvm_component parent = null);
        super.new(path, parent);
        send = new("send", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_transc = transaction::type_id::create("mon_transc", this);

        if (!uvm_config_db #(virtual mux_if)::get(this, "", "mif", mon_mif)) begin
            `uvm_error("MON", "config_db get failed: Unable to access config_bd.");
        end
        else begin 
            `uvm_info("MON", "config_db get successful.", UVM_LOW);
        end

    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin 
            #10;
            mon_transc.a = mon_mif.a;
            mon_transc.b = mon_mif.b;
            mon_transc.c = mon_mif.c;
            mon_transc.d = mon_mif.d;
            mon_transc.sel = mon_mif.sel;
            mon_transc.y = mon_mif.y;

            `uvm_info("MON", $sformatf("Data Rcvd: a = %0d, b = %0d \
            c = %0d, d = %0d, sel = %0d, y = %0d", mon_transc.a, mon_transc.b, 
            mon_transc.c, mon_transc.d, mon_transc.sel, mon_transc.y), UVM_LOW);
            
            send.write(mon_transc);
        end
    endtask
endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_export #(transaction) expt;
    uvm_analysis_imp #(transaction, scoreboard) recv;

    transaction sco_transc;

    function new(input string path = "scoreboard", uvm_component parent = null);
        super.new(path, parent);
        expt = new("expt", this);
        recv = new("recv", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sco_transc = transaction::type_id::create("sco_transc",this);
    endfunction

    virtual function void write (input transaction transc);
        sco_transc = transc;
        `uvm_info("SCO", $sformatf("Data Rcvd: a = %0d, b = %0d \
        c = %0d, d = %0d, sel = %0d, y = %0d", sco_transc.a, sco_transc.b, 
        sco_transc.c, sco_transc.d, sco_transc.sel, sco_transc.y), UVM_LOW);

        case(sco_transc.sel)
            2'b00: begin 
                if (sco_transc.y == sco_transc.a) begin 
                    `uvm_info("SCO", "Test Passed.", UVM_LOW);
                end
                else begin 
                    `uvm_error("SC0", "Test Failed");
                end
            end

            2'b01: begin 
                if (sco_transc.y == sco_transc.b) begin 
                    `uvm_info("SCO", "Test Passed.", UVM_LOW);
                end
                else begin 
                    `uvm_error("SC0", "Test Failed");
                end
            end

            2'b10: begin 
                if (sco_transc.y == sco_transc.c) begin 
                    `uvm_info("SCO", "Test Passed.", UVM_LOW);
                end
                else begin 
                    `uvm_error("SC0", "Test Failed");
                end
            end

            2'b11: begin 
                if (sco_transc.y == sco_transc.d) begin 
                    `uvm_info("SCO", "Test Passed.", UVM_LOW);
                end
                else begin 
                    `uvm_error("SC0", "Test Failed");
                end
            end
        endcase
    endfunction
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    monitor mon;
    driver drv;
    uvm_sequencer #(transaction) seqr;

    function new(input string path = "agent", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv", this);
        mon = monitor::type_id::create("mon", this);
        seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

class environment extends uvm_env;
    `uvm_component_utils(environment)

    scoreboard sco;
    agent agt;

    function new(input string path = "environment", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sco = scoreboard::type_id::create("sco", this);
        agt = agent::type_id::create("agt", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agt.mon.send.connect(sco.expt);
        sco.expt.connect(sco.recv);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    generator gen;
    environment env;

    function new(input string path = "test", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        gen = generator::type_id::create("gen");
        env = environment::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            gen.start(env.agt.seqr);
        phase.drop_objection(this);
    endtask
endclass

module tb_mux();
    mux_if mif();

    mux dut 
    (
        .a(mif.a),
        .b(mif.b),
        .c(mif.c),
        .d(mif.d),
        .sel(mif.sel),
        .y(mif.y)
    );

    initial begin 
        uvm_config_db #(virtual mux_if)::set(null,"uvm_test_top.env.agt*", "mif", mif);

        run_test("test");
    end
endmodule