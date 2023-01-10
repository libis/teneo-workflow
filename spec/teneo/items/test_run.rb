# frozen_string_literal: true

require "teneo/workflow/run"

class TestRun
  include Teneo::Workflow::Run

  attr_accessor :name, :config, :options

  attr_reader :job, :properties

  def initialize(job, name = nil)
    @name = name || self.class.name
    @config = {}
    @job = job
    @options = {}
    @properties = {}
  end

  def save!
  end

end
