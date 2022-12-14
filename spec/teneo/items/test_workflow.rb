# frozen_string_literal: true

require "teneo/workflow/job"


class TestWorkflow
  include Teneo::Workflow::Workflow

  attr_accessor :name, :description, :config

  def initialize()
    @name = "TestWorkflow"
    @description = ''
    @config = {}
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
