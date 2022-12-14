# frozen_string_literal: true

require "teneo/workflow/run"

class TestRun
  include Teneo::Workflow::Run

  attr_accessor :name, :config

  attr_reader :job, :options, :properties

  def initialize(job, name = nil)
    @name = name || self.class.name
    @config = {}
    @job = job
    @otions = {}
    @properties = {}
  end

  def save!
  end

end
