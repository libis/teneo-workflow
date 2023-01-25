# frozen_string_literal: true

require "stringio"
require "semantic_logger"

require 'pry-byebug'
require "amazing_print"


basedir = File.absolute_path File.join(File.dirname(__FILE__))
dirname = File.join(basedir, "items")

TestStatusLog = Struct.new(:status, :run, :task, :item, :progress, :max, keyword_init: true) do
  include Teneo::Workflow::StatusLog

  def initialize(status: nil, run: nil, task: nil, item: nil, progress: nil, max: nil)
    task = task.namepath if task.is_a?(Teneo::Workflow::Task)
    item = item.namepath if item.is_a?(Teneo::Workflow::WorkItem) || item.is_a?(Teneo::Workflow::Job)
    run = run.name if run.is_a?(Teneo::Workflow::Run)
    super status: status, run: run, task: task, item: item, progress: progress, max: max
  end

  def update_status(status: nil, progress: nil, max: nil)
    self.status = status if status
    self.progress = progress if progress
    self.max = max if max
  end

  def self.status_list
    @status_list ||= []
  end

  def self.create_status(**info)
    entry = self.new(**info)
    status_list << entry
    entry
  end

  def self.find_last(**info)
    i = info.compact
    status_list.reverse.find do |x|
      i.keys.all? {|k| x[k] == i[k]}
    end
  end

  def self.find_all(**info)
    i = info.compact
    status_list.reverse.select do |x|
      i.keys.all? {|k| x[k] == i[k]}
    end.reverse
  end

  def self.find_all_last(**info)
    self.find_all(**info).last
  end

end

Teneo::Workflow.config.status_log = TestStatusLog

TestMessageLog = Struct.new(:severity, :run, :task, :item, :message, :data, keyword_init: true) do
  include Teneo::Workflow::MessageLog

  def self.add_entry(severity:, item:, task:, run:, message:, **data)
    @message_log ||= []
    @message_log << self.new(severity: severity, item: item, task: task, run: run, message: message, data: data)
  end

  def self.get_entries
    @message_log
  end

end

Teneo::Workflow.config.message_log = TestMessageLog


def show(run)
  puts 'run'
  puts run.to_yaml
  puts "output:"
  ap $logoutput.string.lines.to_a.map { |x| x[/(?<=\] ).*/].strip }
  puts "status_log:"
  run.status_log.each { |e| ap e }
end

def check_output(logoutput, sample_out)
  sample_out = sample_out.lines.to_a.map { |x| x.strip }
  output = logoutput.string.lines.to_a.map { |x| x[/(?<=\] ).*/].strip }

  # puts 'output:'
  # ap output

  expect(output.size).to eq sample_out.size
  output.each_with_index do |o, i|
    expect(o).to eq sample_out[i]
  end
end

def check_status_log(status_log, sample_status_log)
  # puts 'status_log:'
  # status_log.each { |e| ap e }
  expect(status_log.size).to eq sample_status_log.size
  sample_status_log.each_with_index do |h, i|
    h.keys.each { |key| expect(status_log[i][key.to_s]).to eq h[key] }
  end
end

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
        input: { dirname: dirname, checksum_type: "SHA256" },
      )
      job
    }

    let(:run) {
      r = job.make_run
      r.clear_appenders!
      $logoutput = r.add_appender(:string_io, 'logoutput', level: :debug).sio
      r.add_appender(:stdout, level: :debug)
      job.execute(r)
      r.flush
      r
    }

    it "should contain three tasks" do
      expect(workflow.config[:tasks].size).to eq 2
      expect(workflow.config[:tasks].first[:class]).to eq "CollectFiles"
      expect(workflow.config[:tasks].last[:name]).to eq "ProcessFiles"
    end

    it "should camelize the workitem name" do
      binding.pry
      show run
      expect(run.options["CollectFiles"][:parameters]["location"]).to eq dirname
      expect(run.size).to eq 1
      expect(run.items.size).to eq 1
      expect(run.items.first.class).to eq TestDirItem
      expect(run.items.first.size).to eq 5
      expect(run.items.first.items.size).to eq 5
      expect(run.items.first.items.first.class).to eq TestFileItem

      expect(run.job.items.first.name).to eq "Items"

      run.job.items.first.each_with_index do |x, i|
        expect(x.name).to eq %w[TestDirItem.rb TestFileItem.rb TestRun.rb][i]
      end
    end

    it "should return expected debug output" do
      run

      show run
      check_output $logoutput, <<~STR
                      INFO -- Run - TestRun : Ingest run started.
                      INFO -- Run - TestRun : Running subtask (1/2): CollectFiles
                     DEBUG -- CollectFiles - TestRun : Processing subitem (1/1): items
                     DEBUG -- CollectFiles - items : Processing subitem (1/5): test_dir_item.rb
                     DEBUG -- CollectFiles - items : Processing subitem (2/5): test_file_item.rb
                     DEBUG -- CollectFiles - items : Processing subitem (3/5): test_job.rb
                     DEBUG -- CollectFiles - items : Processing subitem (4/5): test_run.rb
                     DEBUG -- CollectFiles - items : Processing subitem (5/5): test_workflow.rb
                     DEBUG -- CollectFiles - items : 5 of 5 subitems passed
                     DEBUG -- CollectFiles - TestRun : 1 of 1 subitems passed
                      INFO -- Run - TestRun : Running subtask (2/2): ProcessFiles
                      INFO -- ProcessFiles - TestRun : Running subtask (1/2): ChecksumTester
                     DEBUG -- ProcessFiles/ChecksumTester - TestRun : Processing subitem (1/1): items
                     DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (1/5): test_dir_item.rb
                     DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (2/5): test_file_item.rb
                     DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (3/5): test_job.rb
                     DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (4/5): test_run.rb
                     DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (5/5): test_workflow.rb
                     DEBUG -- ProcessFiles/ChecksumTester - items : 5 of 5 subitems passed
                     DEBUG -- ProcessFiles/ChecksumTester - TestRun : 1 of 1 subitems passed
                      INFO -- ProcessFiles - TestRun : Running subtask (2/2): CamelizeName
                     DEBUG -- ProcessFiles/CamelizeName - TestRun : Processing subitem (1/1): items
                     DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (1/5): test_dir_item.rb
                     DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (2/5): test_file_item.rb
                     DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (3/5): test_job.rb
                     DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (4/5): test_run.rb
                     DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (5/5): test_workflow.rb
                     DEBUG -- ProcessFiles/CamelizeName - Items : 5 of 5 subitems passed
                     DEBUG -- ProcessFiles/CamelizeName - TestRun : 1 of 1 subitems passed
                      INFO -- ProcessFiles - TestRun : Done
                      INFO -- Run - TestRun : Done
                   STR

      check_status_log run.status_log, [
        { task: "Run", status: :DONE, progress: 2, max: 2 },
        { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
        { task: "ProcessFiles", status: :DONE, progress: 2, max: 2 },
        { task: "ProcessFiles/ChecksumTester", status: :DONE, progress: 1, max: 1 },
        { task: "ProcessFiles/CamelizeName", status: :DONE, progress: 1, max: 1 },
      ]

      check_status_log run.items.first.status_log, [
        { task: "CollectFiles", status: :DONE, progress: 5, max: 5 },
        { task: "ProcessFiles/ChecksumTester", status: :DONE, progress: 5, max: 5 },
        { task: "ProcessFiles/CamelizeName", status: :DONE, progress: 5, max: 5 },
      ]

      check_status_log run.items.first.items.first.status_log, [
        { task: "CollectFiles", status: :DONE, progress: nil, max: nil },
        { task: "ProcessFiles/ChecksumTester", status: :DONE, progress: nil, max: nil },
        { task: "ProcessFiles/CamelizeName", status: :DONE, progress: nil, max: nil },
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
        input: { dirname: dirname, processing: processing, force_run: force_run },
      )
      job
    }

    let(:run) {
      r = job.make_run
      r.clear_appenders!
      $logoutput = r.add_appender(string_io: 'logoutput', level: :info).sio
      r.add_appender(:stdout, level: :debug)
      r.reopen
      job.execute(r)
      r.flush
      r
    }

    context "without forcing final task" do
      let(:force_run) { false }

      context "when processing successfully" do
        let(:processing) { "success" }

        it "should run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                         INFO -- Run - TestRun : Ingest run started.
                         INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                         INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         INFO -- ProcessingTask - TestRun : Task success
                         INFO -- ProcessingTask - TestRun : Task success
                         INFO -- ProcessingTask - TestRun : Task success
                         INFO -- Run - TestRun : Running subtask (3/3): FinalTask
                         INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
                         INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
                         INFO -- FinalTask - TestRun : Final processing of test_run.rb
                         INFO -- Run - TestRun : Done
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :DONE, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :DONE, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :DONE, progress: 3, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :DONE },
            { task: "FinalTask", status: :DONE },
          ]
        end
      end

      context "when stopped with async_halt" do
        let(:processing) { "async_halt" }

        it "should not run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
                         ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
                         ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
                          WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
                          WARN -- ProcessingTask - TestRun : 1 subitem(s) halted in async process
                          WARN -- Run - TestRun : 1 subtask(s) halted in async process
                          INFO -- Run - TestRun : Waiting for halted async process
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :ASYNC_HALT, progress: 2, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :ASYNC_HALT, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :ASYNC_HALT, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :ASYNC_HALT },
          ]
        end
      end

      context "when stopped with fail" do
        let(:processing) { "fail" }

        it "should not run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - items : 3 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 2, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
          ]
        end
      end

      context "when stopped with error" do
        let(:processing) { "error" }

        it "should not run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/3): Task failed with WorkflowError exception
                         ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/3): Task failed with WorkflowError exception
                         ERROR -- ProcessingTask - items/test_run.rb : Error processing subitem (3/3): Task failed with WorkflowError exception
                         ERROR -- ProcessingTask - items : 3 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 2, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
          ]
        end
      end

      context "when stopped with abort" do
        let(:processing) { "abort" }

        it "should not run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
                         ERROR -- ProcessingTask - items : 1 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 2, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
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

          show run
          check_output $logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
 INFO -- Run - TestRun : Done
STR

          check_status_log run.status_log, [
            { task: "Run", status: :DONE, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :DONE, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :DONE, progress: 3, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :DONE },
            { task: "FinalTask", status: :DONE },
          ]
        end
      end

      context "when stopped with async_halt" do
        let(:processing) { "async_halt" }

        it "should run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
                         ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
                         ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
                          WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
                          WARN -- ProcessingTask - TestRun : 1 subitem(s) halted in async process
                          INFO -- Run - TestRun : Running subtask (3/3): FinalTask
                          INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_run.rb
                          WARN -- Run - TestRun : 1 subtask(s) halted in async process
                          INFO -- Run - TestRun : Waiting for halted async process
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :ASYNC_HALT, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :ASYNC_HALT, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :ASYNC_HALT, progress: 3, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :ASYNC_HALT },
            { task: "FinalTask", status: :DONE },
          ]
        end
      end

      context "when stopped with fail" do
        let(:processing) { "fail" }

        it "should run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - items : 3 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                          INFO -- Run - TestRun : Running subtask (3/3): FinalTask
                          INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_run.rb
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR
          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
            { task: "FinalTask", status: :DONE },
          ]
        end

        it "should run final task during retry" do
          run

          $logoutput.truncate(0)
          run.run :retry

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - TestRun : Task failed with failed status
                         ERROR -- ProcessingTask - items : 3 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                          INFO -- Run - TestRun : Running subtask (3/3): FinalTask
                          INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_run.rb
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR
          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
            { task: "Run", status: :FAILED, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
            { task: "FinalTask", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
            { task: "FinalTask", status: :DONE },
          ]
        end
      end

      context "when stopped with error" do
        let(:processing) { "error" }

        it "should run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/3): Task failed with WorkflowError exception
                         ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/3): Task failed with WorkflowError exception
                         ERROR -- ProcessingTask - items/test_run.rb : Error processing subitem (3/3): Task failed with WorkflowError exception
                         ERROR -- ProcessingTask - items : 3 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                          INFO -- Run - TestRun : Running subtask (3/3): FinalTask
                          INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_run.rb
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR
          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
            { task: "FinalTask", status: :DONE },
          ]
        end
      end

      context "when stopped with abort" do
        let(:processing) { "abort" }

        it "should run final task" do
          run

          show run
          check_output $logoutput, <<~STR
                          INFO -- Run - TestRun : Ingest run started.
                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
                         FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
                         ERROR -- ProcessingTask - items : 1 subitem(s) failed
                         ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
                          INFO -- Run - TestRun : Running subtask (3/3): FinalTask
                          INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
                          INFO -- FinalTask - TestRun : Final processing of test_run.rb
                         ERROR -- Run - TestRun : 1 subtask(s) failed
                          INFO -- Run - TestRun : Failed
                       STR

          check_status_log run.status_log, [
            { task: "Run", status: :FAILED, progress: 3, max: 3 },
            { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
            { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
            { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
          ]

          check_status_log run.items.first.status_log, [
            { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
            { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
            { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
          ]

          check_status_log run.items.first.items.first.status_log, [
            { task: "CollectFiles", status: :DONE },
            { task: "ProcessingTask", status: :FAILED },
            { task: "FinalTask", status: :DONE },
          ]
        end
      end
    end
  end
end
