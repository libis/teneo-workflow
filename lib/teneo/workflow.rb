# frozen_string_literal: true

require "dry-configurable"

require_relative "workflow/version"

module Teneo
  module Workflow
    autoload :Action, "teneo/workflow/action"
    autoload :Job, "teneo/workflow/job"
    autoload :MessageRegistry, "teneo/workflow/message_registry"
    autoload :Run, "teneo/workflow/run"
    autoload :StatusLog, "teneo/workflow/status_log"
    autoload :Task, "teneo/workflow/task"
    autoload :TaskGroup, "teneo/workflow/task_group"
    autoload :TaskRunner, "teneo/workflow/task_runner"
    autoload :WorkItem, "teneo/workflow/work_item"
    autoload :FileItem, "teneo/workflow/file_item"

    module Base
      autoload :Logging, "teneo/workflow/base/logging"
      autoload :StatusEnum, "teneo/workflow/base/status_enum"
      autoload :TaskConfiguration, "teneo/workflow/base/task_configuration"
      autoload :TaskExecution, "teneo/workflow/base/task_execution"
      autoload :TaskHierarchy, "teneo/workflow/base/task_hierarchy"
      autoload :TaskLogging, "teneo/workflow/base/task_logging"
      autoload :TaskStatus, "teneo/workflow/base/task_status"
    end

    extend Dry::Configurable

    def require_all(dir)
      Dir.glob(File.join(dir, "*.rb")).each do |filename|
        require filename
      end
    end

    setting :workdir, "./work"
    setting :taskdir, "./tasks"
    setting :itemdir, "./items"

    setting :logger, $stdout

    setting :status_log, Teneo::Workflow::StatusLog
  end
end
