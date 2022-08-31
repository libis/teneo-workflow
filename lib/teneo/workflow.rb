# frozen_string_literal: true

require "dry-configurable"

require_relative "workflow/version"

module Teneo
  module Workflow
    autoload :Action, "teneo/workflow/action"
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
      autoload :ItemLogging, "teneo/workflow/base/item_logging"
      autoload :StatusEnum, "teneo/workflow/base/status_enum"
      autoload :TaskConfiguration, "teneo/workflow/base/task_configuration"
      autoload :TaskExecution, "teneo/workflow/base/task_execution"
      autoload :TaskHierarchy, "teneo/workflow/base/task_hierarchy"
      autoload :TaskLogging, "teneo/workflow/base/task_logging"
      autoload :TaskStatus, "teneo/workflow/base/task_status"
    end

    def require_all(dir)
      Dir.glob(File.join(dir, "*.rb")).each do |filename|
        require filename
      end
    end

    extend Dry::Configurable

    # The directory base path for items
    setting :taskdir, default: "./items"

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