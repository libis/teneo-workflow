# frozen_string_literal: true

require "teneo/workflow/message_log"

TestMessageLog = Struct.new(:severity, :run, :task, :item, :message, :data, keyword_init: true) do
  include Teneo::Workflow::MessageLog

  def self.add_entry(severity:, item:, task:, run:, message:, **data)
    @message_log ||= []
    @message_log << new(severity: severity, item: item, task: task, run: run, message: message, data: data)
  end

  def self.get_entries
    @message_log
  end
end
