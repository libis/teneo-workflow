require_relative "spec_helper"

require "teneo/workflow"

RSpec.describe "Task" do
  it "should create a default task" do
    task = ::Teneo::Workflow::Task.new nil

    expect(task.parent).to eq nil
    expect(task.name).to eq "Task"
  end
end
