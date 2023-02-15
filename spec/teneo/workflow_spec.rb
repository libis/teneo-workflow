# frozen_string_literal: true

require "stringio"

require "pry-byebug"
require "amazing_print"

basedir = File.absolute_path File.join(File.dirname(__FILE__))
datadir = File.join(basedir, "data")
dirname = File.join(basedir, "items")

TestStatusLog = Struct.new(:status, :progress, :max, :created_at, :updated_at, keyword_init: true) do
  include Teneo::Workflow::StatusLog

  def initialize(status: nil, progress: nil, max: nil)
    t = Time.now
    super status: status, progress: progress, max: max, created_at: t, updated_at: t
  end

  def update_status(status: nil, progress: nil, max: nil)
    self.status = status if status
    self.progress = progress if progress
    self.max = max if max
    self.updated_at = Time.now
  end

  def self.status_list
    @status_list ||= {}
  end

  def set_status(status:, run: nil, task: nil, item: nil, progress: nil, max: nil)
    r = super
    key, _ = parse_info()
    return r
  end

  def self.create_status(**info)
    key, info = parse_info(**info)
    entry = self.new(**info)
    status_list[key] = entry
    key.merge(entry.to_h)
  end

  def self.find_entry(run: nil, task: nil, item: nil)
    key, _ = parse_info(run: run, task: task, item: item)
    status_list[key]
  end

  def self.find_all(**info)
    i = info.compact
    status_list.select do |k, v|
      i.keys.all? { |i_key| k[i_key] == i[i_key] }
    end
  end

  # def self.find_last
  # end

  def self.clear!
    @status_list = {}
  end

  def self.parse_info(**info)
    run = info.delete(:run)
    task = info.delete(:task)
    item = info.delete(:item)
    run ||= task.is_a?(Teneo::Workflow::Task) ? task.run : nil
    run = run.is_a?(Teneo::Workflow::Run) ? run.name : run
    task = task.is_a?(Teneo::Workflow::Task) ? task.namepath : task
    item = item.is_a?(Teneo::Workflow::WorkItem) || item.is_a?(Teneo::Workflow::Job) ? item.namepath : item
    key = { run: run, task: task, item: item }
    [key, info]
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
  puts "run"
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
  # context "Version" do
  #   it "has a version number" do
  #     expect(Teneo::Workflow::VERSION).not_to be nil
  #   end
  # end

  context "TestWorkflow" do
    before :each do
      Teneo::Workflow.configure do |cfg|
        cfg.itemdir = dirname
        cfg.taskdir = File.join(basedir, "tasks")
        cfg.workdir = File.join(basedir, "work")
      end
      Teneo::Workflow.require_all(dirname)
      TestStatusLog.clear!
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
      binding.pry
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

  #   context "Test run_always" do
  #     before :each do
  #       Teneo::Workflow.configure do |cfg|
  #         cfg.itemdir = dirname
  #         cfg.taskdir = File.join(basedir, "tasks")
  #         cfg.workdir = File.join(basedir, "work")
  #       end
  #       Teneo::Workflow.require_all(dirname)
  #     end

  #     let(:workflow) {
  #       workflow = TestWorkflow.new
  #       workflow.description = "Workflow for testing run_always options"
  #       workflow.configure(
  #         tasks: [
  #           { class: "CollectFiles", recursive: true },
  #           { class: "ProcessingTask", recursive: true },
  #           { class: "FinalTask", recursive: true },
  #         ],
  #         input: {
  #           dirname: { default: ".", propagate_to: [{ task: "CollectFiles", parameter: "location" }] },
  #           processing: { default: "success", propagate_to: [{ task: "ProcessingTask", parameter: "config" }] },
  #           force_run: { default: false, propagate_to: [{ task: "FinalTask", parameter: "run_always" }] },
  #         },
  #       )
  #       workflow
  #     }

  #     let(:processing) { "success" }
  #     let(:force_run) { false }

  #     let(:job) {
  #       job = TestJob.new(workflow)
  #       job.description = "Job for testing run_always"
  #       job.configure(
  #         input: { dirname: datadir, processing: processing, force_run: force_run },
  #       )
  #       job
  #     }

  #     let(:run) {
  #       r = job.make_run
  #       r.clear_appenders!
  #       $logoutput = r.add_appender(string_io: "logoutput", level: :info).sio
  #       r.add_appender(:stdout, level: :debug)
  #       r.reopen
  #       job.execute(r)
  #       r.flush
  #       r
  #     }

  #     context "without forcing final task" do
  #       let(:force_run) { false }

  #       context "when processing successfully" do
  #         let(:processing) { "success" }

  #         it "should run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                          INFO -- Run - TestRun : Ingest run started.
  #                          INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                          INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          INFO -- ProcessingTask - TestRun : Task success
  #                          INFO -- ProcessingTask - TestRun : Task success
  #                          INFO -- ProcessingTask - TestRun : Task success
  #                          INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #                          INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #                          INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #                          INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #                          INFO -- Run - TestRun : Done
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :DONE, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :DONE, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :DONE, progress: 3, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :DONE },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end
  #       end

  #       context "when stopped with async_halt" do
  #         let(:processing) { "async_halt" }

  #         it "should not run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
  #                           WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
  #                           WARN -- ProcessingTask - TestRun : 1 subitem(s) halted in async process
  #                           WARN -- Run - TestRun : 1 subtask(s) halted in async process
  #                           INFO -- Run - TestRun : Waiting for halted async process
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :ASYNC_HALT, progress: 2, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :ASYNC_HALT, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :ASYNC_HALT, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :ASYNC_HALT },
  #           ]
  #         end
  #       end

  #       context "when stopped with fail" do
  #         let(:processing) { "fail" }

  #         it "should not run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - items : 3 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 2, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #           ]
  #         end
  #       end

  #       context "when stopped with error" do
  #         let(:processing) { "error" }

  #         it "should not run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/3): Task failed with WorkflowError exception
  #                          ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/3): Task failed with WorkflowError exception
  #                          ERROR -- ProcessingTask - items/test_run.rb : Error processing subitem (3/3): Task failed with WorkflowError exception
  #                          ERROR -- ProcessingTask - items : 3 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 2, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #           ]
  #         end
  #       end

  #       context "when stopped with abort" do
  #         let(:processing) { "abort" }

  #         it "should not run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
  #                          ERROR -- ProcessingTask - items : 1 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 2, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #           ]
  #         end
  #       end
  #     end

  #     context "with forcing final task" do
  #       let(:force_run) { true }

  #       context "when processing successfully" do
  #         let(:processing) { "success" }

  #         it "should run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<STR
  #  INFO -- Run - TestRun : Ingest run started.
  #  INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #  INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #  INFO -- ProcessingTask - TestRun : Task success
  #  INFO -- ProcessingTask - TestRun : Task success
  #  INFO -- ProcessingTask - TestRun : Task success
  #  INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #  INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #  INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #  INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #  INFO -- Run - TestRun : Done
  # STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :DONE, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :DONE, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :DONE, progress: 3, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :DONE },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end
  #       end

  #       context "when stopped with async_halt" do
  #         let(:processing) { "async_halt" }

  #         it "should run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
  #                           WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
  #                           WARN -- ProcessingTask - TestRun : 1 subitem(s) halted in async process
  #                           INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #                           INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #                           WARN -- Run - TestRun : 1 subtask(s) halted in async process
  #                           INFO -- Run - TestRun : Waiting for halted async process
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :ASYNC_HALT, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :ASYNC_HALT, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :ASYNC_HALT, progress: 3, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :ASYNC_HALT },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end
  #       end

  #       context "when stopped with fail" do
  #         let(:processing) { "fail" }

  #         it "should run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - items : 3 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                           INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #                           INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR
  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end

  #         it "should run final task during retry" do
  #           run

  #           $logoutput.truncate(0)
  #           run.run :retry

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - TestRun : Task failed with failed status
  #                          ERROR -- ProcessingTask - items : 3 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                           INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #                           INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR
  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #             { task: "Run", status: :FAILED, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 3, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #             { task: "FinalTask", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end
  #       end

  #       context "when stopped with error" do
  #         let(:processing) { "error" }

  #         it "should run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/3): Task failed with WorkflowError exception
  #                          ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/3): Task failed with WorkflowError exception
  #                          ERROR -- ProcessingTask - items/test_run.rb : Error processing subitem (3/3): Task failed with WorkflowError exception
  #                          ERROR -- ProcessingTask - items : 3 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                           INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #                           INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR
  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end
  #       end

  #       context "when stopped with abort" do
  #         let(:processing) { "abort" }

  #         it "should run final task" do
  #           run

  #           show run
  #           check_output $logoutput, <<~STR
  #                           INFO -- Run - TestRun : Ingest run started.
  #                           INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
  #                           INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
  #                          FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
  #                          ERROR -- ProcessingTask - items : 1 subitem(s) failed
  #                          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
  #                           INFO -- Run - TestRun : Running subtask (3/3): FinalTask
  #                           INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
  #                           INFO -- FinalTask - TestRun : Final processing of test_run.rb
  #                          ERROR -- Run - TestRun : 1 subtask(s) failed
  #                           INFO -- Run - TestRun : Failed
  #                        STR

  #           check_status_log run.status_log, [
  #             { task: "Run", status: :FAILED, progress: 3, max: 3 },
  #             { task: "CollectFiles", status: :DONE, progress: 1, max: 1 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 1, max: 1 },
  #             { task: "FinalTask", status: :DONE, progress: 1, max: 1 },
  #           ]

  #           check_status_log run.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE, progress: 3, max: 3 },
  #             { task: "ProcessingTask", status: :FAILED, progress: 0, max: 3 },
  #             { task: "FinalTask", status: :DONE, progress: 3, max: 3 },
  #           ]

  #           check_status_log run.items.first.items.first.status_log, [
  #             { task: "CollectFiles", status: :DONE },
  #             { task: "ProcessingTask", status: :FAILED },
  #             { task: "FinalTask", status: :DONE },
  #           ]
  #         end
  #       end
  #     end
  #   end
end
