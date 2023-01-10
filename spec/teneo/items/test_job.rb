# frozen_string_literal: true

require "teneo/workflow/job"

require_relative 'test_run'

class TestJob
  include Teneo::Workflow::Job

  attr_accessor :name, :description, :input, :tasks

  attr_reader :workflow, :runs, :items, :work_dir

  def initialize(workflow)
    @name = "TestJob"
    @description = ''
    @input = {}
    @tasks = []
    @workflow = workflow
    @runs = []
    @items = []
    @work_dir = File.join(Teneo::Workflow.config.workdir, @name)
  end

  def <<(item)
    @items << item
  end

  alias add_item <<

  def make_run
    run = TestRun.new(self, run_name)
    @runs << run
    run.save!
    run
  end

  def last_run
    @runs.last
  end  

  def save!
  end

end
