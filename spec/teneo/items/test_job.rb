# frozen_string_literal: true

require "teneo/workflow/job"

require_relative 'test_run'

class TestJob
  include Teneo::Workflow::Job

  attr_accessor :name, :description, :config

  attr_reader :workflow, :runs, :items, :work_dir

  def initialize(workflow)
    @name = "TestJob"
    @description = ''
    @config = {}
    @workflow = workflow
    @runs = []
    @items = []
    @work_dir = File.join(Teneo::Workflow.config.workdir, @name)
  end

  def <<(run)
    @runs << run
  end

  def make_run
    TestRun.new(self, run_name)
  end

  def last_run
    @runs.last
  end  

  def save!
  end

end
