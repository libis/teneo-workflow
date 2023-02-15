# frozen_string_literal: true

require "stringio"

require "pry-byebug"
require "amazing_print"

basedir = File.absolute_path File.join(File.dirname(__FILE__))
datadir = File.join(basedir, "data")
dirname = File.join(basedir, "items")

require_relative "test_status_log"
require_relative "test_message_log"
require_relative "workflow_test_helpers.rb"

Teneo::Workflow.config.status_log = TestStatusLog
Teneo::Workflow.config.message_log = TestMessageLog

RSpec.describe Teneo::Workflow do
  context "Version" do
    it "has a version number" do
      expect(Teneo::Workflow::VERSION).not_to be nil
    end
  end

  context "TestWorkflow" do
    before :each do
      Teneo::Workflow.configure do |cfg|
        cfg.itemdir = dirname
        cfg.taskdir = File.join(basedir, "tasks")
        cfg.workdir = File.join(basedir, "work")
      end
      Teneo::Workflow.require_all(dirname)
    end

    let(:workflow) {
      workflow = TestWorkflow.new
      workflow.description = "Workflow for testing"
      workflow.configure(
        tasks: [
          { class: "CollectFiles", recursive: true },
          {
            name: "ProcessFiles", recursive: false,
            tasks: [
              { class: "ChecksumTester", recursive: true },
              { class: "CamelizeName", recursive: true },
            ],
          },
        ],
        input: {
          dirname: { default: ".", propagate_to: [{ task: "CollectFiles", parameter: "location" }] },
          checksum_type: { default: "SHA1", propagate_to: [{ task: "ProcessFiles/ChecksumTester" }] },
        },
      )
      workflow
    }

    let(:job) {
      job = TestJob.new(workflow)
      job.description = "Job for testing"
      job.configure(
        input: { dirname: datadir, checksum_type: "SHA256" },
      )
      job
    }

    let(:run) {
      r = job.make_run
      r.clear_appenders!
      $logoutput = r.add_appender(:string_io, "logoutput", level: :debug).sio
      job.execute(r)
      r
    }

    it "should contain three tasks" do
      expect(workflow.config[:tasks].size).to eq 2
      expect(workflow.config[:tasks].first[:class]).to eq "CollectFiles"
      expect(workflow.config[:tasks].last[:name]).to eq "ProcessFiles"
    end

    it "should camelize the workitem name" do
      run
      expect(run.options["CollectFiles"][:parameters]["location"]).to eq datadir
      expect(run.size).to eq 1
      expect(run.items.size).to eq 1
      expect(run.items.first.class).to eq TestDirItem
      expect(run.items.first.size).to eq 1
      expect(run.items.first.items.first.class).to eq TestDirItem
      expect(run.items.first.items.first.size).to eq 5
      expect(run.items.first.items.first.items.first.class).to eq TestFileItem

      expect(run.job.items.first.name).to eq "Data"
      expect(run.job.items.first.items.first.name).to eq "SubFolder"

      run.job.items.first.items.first.items.each_with_index do |x, i|
        expect(x.name).to eq %w[AaaPpp.txt BbbQqq.txt CccRrr.txt DddSss.txt EeeTtt.txt][i]
      end
    end

    it "should return expected debug output" do
      run
      check_output $logoutput, <<~STR
         INFO -- Run - TestRun : Ingest run started.
         INFO -- Run - TestRun : Running subtask (1/2): CollectFiles
        DEBUG -- CollectFiles - TestRun : Processing subitem (1/1): data
        DEBUG -- CollectFiles - data : Processing subitem (1/1): sub_folder
        DEBUG -- CollectFiles - data/sub_folder : Processing subitem (1/5): aaa_ppp.txt
        DEBUG -- CollectFiles - data/sub_folder : Processing subitem (2/5): bbb_qqq.txt
        DEBUG -- CollectFiles - data/sub_folder : Processing subitem (3/5): ccc_rrr.txt
        DEBUG -- CollectFiles - data/sub_folder : Processing subitem (4/5): ddd_sss.txt
        DEBUG -- CollectFiles - data/sub_folder : Processing subitem (5/5): eee_ttt.txt
        DEBUG -- CollectFiles - data/sub_folder : 5 of 5 subitems passed
        DEBUG -- CollectFiles - data : 1 of 1 subitems passed
        DEBUG -- CollectFiles - TestRun : 1 of 1 subitems passed
         INFO -- Run - TestRun : Running subtask (2/2): ProcessFiles
         INFO -- ProcessFiles - TestRun : Running subtask (1/2): ChecksumTester
        DEBUG -- ProcessFiles/ChecksumTester - TestRun : Processing subitem (1/1): data
        DEBUG -- ProcessFiles/ChecksumTester - data : Processing subitem (1/1): sub_folder
        DEBUG -- ProcessFiles/ChecksumTester - data/sub_folder : Processing subitem (1/5): aaa_ppp.txt
        DEBUG -- ProcessFiles/ChecksumTester - data/sub_folder : Processing subitem (2/5): bbb_qqq.txt
        DEBUG -- ProcessFiles/ChecksumTester - data/sub_folder : Processing subitem (3/5): ccc_rrr.txt
        DEBUG -- ProcessFiles/ChecksumTester - data/sub_folder : Processing subitem (4/5): ddd_sss.txt
        DEBUG -- ProcessFiles/ChecksumTester - data/sub_folder : Processing subitem (5/5): eee_ttt.txt
        DEBUG -- ProcessFiles/ChecksumTester - data/sub_folder : 5 of 5 subitems passed
        DEBUG -- ProcessFiles/ChecksumTester - data : 1 of 1 subitems passed
        DEBUG -- ProcessFiles/ChecksumTester - TestRun : 1 of 1 subitems passed
         INFO -- ProcessFiles - TestRun : Running subtask (2/2): CamelizeName
        DEBUG -- ProcessFiles/CamelizeName - TestRun : Processing subitem (1/1): data
        DEBUG -- ProcessFiles/CamelizeName - Data : Processing subitem (1/1): sub_folder
        DEBUG -- ProcessFiles/CamelizeName - Data/SubFolder : Processing subitem (1/5): aaa_ppp.txt
        DEBUG -- ProcessFiles/CamelizeName - Data/SubFolder : Processing subitem (2/5): bbb_qqq.txt
        DEBUG -- ProcessFiles/CamelizeName - Data/SubFolder : Processing subitem (3/5): ccc_rrr.txt
        DEBUG -- ProcessFiles/CamelizeName - Data/SubFolder : Processing subitem (4/5): ddd_sss.txt
        DEBUG -- ProcessFiles/CamelizeName - Data/SubFolder : Processing subitem (5/5): eee_ttt.txt
        DEBUG -- ProcessFiles/CamelizeName - Data/SubFolder : 5 of 5 subitems passed
        DEBUG -- ProcessFiles/CamelizeName - Data : 1 of 1 subitems passed
        DEBUG -- ProcessFiles/CamelizeName - TestRun : 1 of 1 subitems passed
         INFO -- ProcessFiles - TestRun : Done
         INFO -- Run - TestRun : Done
      STR

      check_status_log run.status_log, [
        { task: "Run", status: :done, progress: 2, max: 2 },
        { task: "CollectFiles", status: :done, progress: 1, max: 1 },
        { task: "ProcessFiles", status: :done, progress: 2, max: 2 },
        { task: "ProcessFiles/ChecksumTester", status: :done, progress: 1, max: 1 },
        { task: "ProcessFiles/CamelizeName", status: :done, progress: 1, max: 1 },
      ]

      check_status_log job.status_log, [
        { task: "Run", status: :done, progress: 2, max: 2 },
        { task: "CollectFiles", status: :done, progress: 1, max: 1 },
        { task: "ProcessFiles", status: :done, progress: 2, max: 2 },
        { task: "ProcessFiles/ChecksumTester", status: :done, progress: 1, max: 1 },
        { task: "ProcessFiles/CamelizeName", status: :done, progress: 1, max: 1 },
      ]

      check_status_log run.items.first.status_log, [
        { task: "CollectFiles", status: :done, progress: 1, max: 1 },
        { task: "ProcessFiles/ChecksumTester", status: :done, progress: 1, max: 1 },
        { task: "ProcessFiles/CamelizeName", status: :done, progress: 1, max: 1 },
      ]

      check_status_log run.items.first.items.first.status_log, [
        { task: "CollectFiles", status: :done, progress: 5, max: 5 },
        { task: "ProcessFiles/ChecksumTester", status: :done, progress: 5, max: 5 },
        { task: "ProcessFiles/CamelizeName", status: :done, progress: 5, max: 5 },
      ]

      check_status_log run.items.first.items.first.items.first.status_log, [
        { task: "CollectFiles", status: :done, progress: nil, max: nil },
        { task: "ProcessFiles/ChecksumTester", status: :done, progress: nil, max: nil },
        { task: "ProcessFiles/CamelizeName", status: :done, progress: nil, max: nil },
      ]
    end
  end

  context "Test run_always" do
    before :each do
      Teneo::Workflow.configure do |cfg|
        cfg.itemdir = dirname
        cfg.taskdir = File.join(basedir, "tasks")
        cfg.workdir = File.join(basedir, "work")
      end
      Teneo::Workflow.require_all(dirname)
    end

    let(:workflow) {
      workflow = TestWorkflow.new
      workflow.description = "Workflow for testing run_always options"
      workflow.configure(
        tasks: [
          { class: "CollectFiles", recursive: true },
          { class: "ProcessingTask", recursive: true },
          { class: "FinalTask", recursive: true },
        ],
        input: {
          dirname: { default: ".", propagate_to: [{ task: "CollectFiles", parameter: "location" }] },
          processing: { default: "success", propagate_to: [{ task: "ProcessingTask", parameter: "config" }] },
          force_run: { default: false, propagate_to: [{ task: "FinalTask", parameter: "run_always" }] },
        },
      )
      workflow
    }

    let(:processing) { "success" }
    let(:force_run) { false }

    let(:job) {
      job = TestJob.new(workflow)
      job.description = "Job for testing run_always"
      job.configure(
        input: { dirname: datadir, processing: processing, force_run: force_run },
      )
      job
    }

    let(:run) {
      r = job.make_run
      r.clear_appenders!
      $logoutput = r.add_appender(:string_io, "logoutput", level: :info).sio
      job.execute(r)
      r
    }

    context "without forcing final task" do
      let(:force_run) { false }

      context "when processing successfully" do
        let(:processing) { "success" }

        it "should run final task" do
          run


          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            INFO -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task success
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            INFO -- Run - TestRun : Done
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :done, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :done, progress: 1, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :done, progress: 1, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :done, progress: 5, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :done },
            { task: "FinalTask", status: :done },
          ]
        end
      end

      context "when stopped with async_halt" do
        let(:processing) { "async_halt" }

        it "should not run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with async_halt status
            WARN -- ProcessingTask - data/sub_folder : 5 subitem(s) stopped because remote process failed
            WARN -- ProcessingTask - data : 1 subitem(s) stopped because remote process failed
            WARN -- ProcessingTask - TestRun : 1 subitem(s) stopped because remote process failed
            WARN -- Run - TestRun : 1 subtask(s) stopped because remote process failed
            INFO -- Run - TestRun : Remote process failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :async_halt, progress: 2, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :async_halt, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :async_halt, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :async_halt, progress: 0, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :async_halt },
          ]
        end
      end

      context "when stopped with fail" do
        let(:processing) { "fail" }

        it "should not run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder : 5 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 2, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
          ]
        end
      end

      context "when stopped with error" do
        let(:processing) { "error" }

        it "should not run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder : 5 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 2, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
          ]
        end
      end

      context "when stopped with abort" do
        let(:processing) { "abort" }

        it "should not run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            FATAL -- ProcessingTask - data/sub_folder : Fatal error processing subitem aaa_ppp.txt (1/5): Task aborted with WorkflowAbort exception
            ERROR -- ProcessingTask - data/sub_folder : 1 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 2, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
          ]
          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
          ]
        end
      end
    end

    context "with forcing final task" do
      let(:force_run) { true }

      context "when processing successfully" do
        let(:processing) { "success" }

        it "should run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            INFO -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task success
            INFO -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task success
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            INFO -- Run - TestRun : Done
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :done, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :done, progress: 1, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :done, progress: 1, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :done, progress: 5, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :done },
            { task: "FinalTask", status: :done },
          ]
        end
      end

      context "when stopped with async_halt" do
        let(:processing) { "async_halt" }

        it "should run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with async_halt status
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with async_halt status
            WARN -- ProcessingTask - data/sub_folder : 5 subitem(s) stopped because remote process failed
            WARN -- ProcessingTask - data : 1 subitem(s) stopped because remote process failed
            WARN -- ProcessingTask - TestRun : 1 subitem(s) stopped because remote process failed
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            WARN -- Run - TestRun : 1 subtask(s) stopped because remote process failed
            INFO -- Run - TestRun : Remote process failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :async_halt, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :async_halt, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :async_halt, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :async_halt, progress: 0, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :async_halt },
            { task: "FinalTask", status: :done },
          ]
        end
      end

      context "when stopped with fail" do
        let(:processing) { "fail" }

        it "should run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder : 5 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
            { task: "FinalTask", status: :done },
          ]
        end

        it "should run final task during retry" do
          run

          run.execute :retry

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder : 5 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with failed status
            ERROR -- ProcessingTask - data/sub_folder : 5 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
            { task: "FinalTask", status: :done },
          ]
        end
      end

      context "when stopped with error" do
        let(:processing) { "error" }

        it "should run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            ERROR -- ProcessingTask - data/sub_folder/aaa_ppp.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/bbb_qqq.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/ccc_rrr.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/ddd_sss.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder/eee_ttt.txt : Task aborted with WorkflowError exception
            ERROR -- ProcessingTask - data/sub_folder : 5 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
            { task: "FinalTask", status: :done },
          ]
        end
      end

      context "when stopped with abort" do
        let(:processing) { "abort" }

        it "should run final task" do
          run

          check_output $logoutput, <<~STR
            INFO -- Run - TestRun : Ingest run started.
            INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
            INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
            FATAL -- ProcessingTask - data/sub_folder : Fatal error processing subitem aaa_ppp.txt (1/5): Task aborted with WorkflowAbort exception
            ERROR -- ProcessingTask - data/sub_folder : 1 subitem(s) failed
            ERROR -- ProcessingTask - data : 1 subitem(s) failed
            ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
            INFO -- Run - TestRun : Running subtask (3/3): FinalTask
            INFO -- FinalTask - data/sub_folder/aaa_ppp.txt : Final processing
            INFO -- FinalTask - data/sub_folder/bbb_qqq.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ccc_rrr.txt : Final processing
            INFO -- FinalTask - data/sub_folder/ddd_sss.txt : Final processing
            INFO -- FinalTask - data/sub_folder/eee_ttt.txt : Final processing
            ERROR -- Run - TestRun : 1 subtask(s) failed
            INFO -- Run - TestRun : Failed
          STR

          check_status_log run.status_log, [
            { task: "Run", status: :failed, progress: 3, max: 3 },
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 1 },
            { task: "FinalTask", status: :done, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done, progress: 5, max: 5 },
            { task: "ProcessingTask", status: :failed, progress: 0, max: 5 },
            { task: "FinalTask", status: :done, progress: 5, max: 5 },
          ]

          check_status_log run.items.first.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :done },
            { task: "ProcessingTask", status: :failed },
            { task: "FinalTask", status: :done },
          ]
        end
      end
    end
  end
end
