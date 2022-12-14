# frozen_string_literal: true

require "dry-configurable"

require_relative "workflow/version"
require_relative "workflow/exceptions"

module Teneo
  module Workflow
    autoload :FileItem, "teneo/workflow/file_item"
    autoload :Job, "teneo/workflow/job"
    autoload :MessageLog, "teneo/workflow/message_log"
    autoload :Run, "teneo/workflow/run"
    autoload :StatusLog, "teneo/workflow/status_log"
    autoload :Task, "teneo/workflow/task"
    autoload :TaskGroup, "teneo/workflow/task_group"
    autoload :TaskRunner, "teneo/workflow/task_runner"
    autoload :WorkItem, "teneo/workflow/work_item"
    autoload :Workflow, "teneo/workflow/workflow"

    module Base
      autoload :Action, "teneo/workflow/base/action"
      autoload :Logging, "teneo/workflow/base/logging"
      autoload :Status, "teneo/workflow/base/status"
      autoload :StatusEnum, "teneo/workflow/base/status_enum"
      autoload :TaskConfiguration, "teneo/workflow/base/task_configuration"
      autoload :TaskExecution, "teneo/workflow/base/task_execution"
      autoload :TaskHierarchy, "teneo/workflow/base/task_hierarchy"
    end

    def self.require_all(dir)
      Dir.glob(File.join(dir, "*.rb")).each do |filename|
        require filename
      end
    end

    include Base::Logging

    extend Dry::Configurable

    # The directory base path for items
    setting :itemdir, default: "./items"

    # The directory base path for tasks
    setting :taskdir, default: "./tasks"

    # The directory base path for working storage
    setting :workdir, default: "./work"

    # The class implementing the status log
    setting :status_log, default: Class.new.include(Teneo::Workflow::StatusLog)

    # The class implementing the message log
    setting :message_log, default: Class.new.include(Teneo::Workflow::MessageLog)

  end
end
