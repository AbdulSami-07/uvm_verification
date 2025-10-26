`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

localparam DATA_WIDTH = 32;

class transaction extends uvm_sequence_item;
    rand bit [DATA_WIDTH-1:0] a;
    rand bit [DATA_WIDTH-1:0] b;
    bit [DATA_WIDTH:0] y;

    function new(input string path = "transaction");
        super.new(path);
    endfunction

    `uvm_object_utils_begin(transaction)
        `uvm_field_int(a, UVM_DEFAULT);
        `uvm_field_int(b, UVM_DEFAULT);
        `uvm_field_int(y, UVM_DEFAULT);
    `uvm_object_utils_end

endclass


class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)

    transaction t;

    function new (input string path = "generator");
        super.new(path);
    endfunction

    virtual task body();
      t = transaction::type_id::create("t");
        repeat(10) begin
            start_item(t);
            t.randomize();
            finish_item(t);
            `uvm_info("GEN",$sformatf("Data Send: a = %0d, b = %0d",t.a,t.b), UVM_LOW);
        end
    endtask

endclass

class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    transaction tc;
    virtual adder_if #(.DATA_WIDTH(32)) aif;

    function new (input string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        tc = transaction::type_id::create("tc");
        
        if(!uvm_config_db #(virtual adder_if #(.DATA_WIDTH(32)))::get(this,"","aif",aif)) begin
            `uvm_error("DRV","Unable to access uvm_config_db");
        end
    endfunction

    virtual task run_phase (uvm_phase phase);
        forever begin
          seq_item_port.get_next_item(tc);
            aif.a <= tc.a;
            aif.b <= tc.b;
            `uvm_info("DRV",$sformatf("Trigger DUT: a = %0d, b = %0d", tc.a , tc.b), UVM_LOW);
            seq_item_port.item_done();
            #10;
        end
    endtask

endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) send;

    transaction t;

    virtual adder_if #(.DATA_WIDTH(32)) aif;

    function new (input string path = "monitor", uvm_component parent = null);
        super.new(path,parent);
        send = new("send", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        t = transaction::type_id::create("t");

        if (!uvm_config_db #(virtual adder_if #(.DATA_WIDTH(32)))::get(this, "", "aif", aif)) begin
            `uvm_error("MON", "Unable to access the uvm_config_db.");
        end
    endfunction

    virtual task run_phase (uvm_phase phase);
        forever begin
            #10;
            t.a = aif.a;
            t.b = aif.b;
            t.y = aif.y;

          `uvm_info("MON",$sformatf("Data Sent to SCO: a = %0d, b = %0d and y = %0d",t.a, t.b, t.y), UVM_NONE);

            send.write(t);
        end
    endtask

endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard);

    uvm_analysis_imp #(transaction, scoreboard) recv;

    transaction tr;

    function new (input string path = "scoreboard", uvm_component parent = null);
        super.new(path,parent);
        recv = new("recv", this);
    endfunction 

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
    endfunction

    virtual function void write (input transaction t);
        tr = t;
        `uvm_info("SCO", $sformatf("Data rcvd from monitor: a = %0d, b = %0d, and y = %0d", tr.a, tr.b, tr.y), UVM_NONE);
        
        if (tr.y == tr.a + tr.b) begin
          `uvm_info("SCO", "Test Passed.", UVM_LOW);
        end
        else begin
            `uvm_info("SCO", "Test Failed.", UVM_LOW);
        end
    endfunction

endclass


class agent extends uvm_agent;
    `uvm_component_utils(agent)

    monitor m;
    driver d;
    uvm_sequencer #(transaction) seqr;

  function new (input string path = "agent", uvm_component parent = null);
        super.new(path, parent);
  endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
      m = monitor::type_id::create("m", this);
      d = driver::type_id::create("d", this);
      seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass

class env extends uvm_env;
    `uvm_component_utils(env)

    scoreboard s;
    agent a;

    function new (input string path = "env", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      s = scoreboard::type_id::create("s", this);
      a = agent::type_id::create("a", this);
    endfunction

    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        a.m.send.connect(s.recv);
    endfunction

endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    generator g;
    env e;

  function new (input string path = "test", uvm_component parent = null);
        super.new(path, parent);
      endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      g = generator::type_id::create("g", this);
      e = env::type_id::create("e", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            g.start(e.a.seqr);
        phase.drop_objection(this);
    endtask
endclass

module adder_tb();
    adder_if #(.DATA_WIDTH(32)) aif();

  adder #(.DATA_WIDTH(32)) dut (.a(aif.a), .b(aif.b), .y(aif.y));

    initial begin
      uvm_config_db #(virtual adder_if #(.DATA_WIDTH(32)))::set(null, "uvm_test_top.e.a*", "aif", aif);

        run_test("test");
    end
    
endmodule

