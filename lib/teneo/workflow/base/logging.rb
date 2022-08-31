# frozen_string_literal: true

require "teneo/logger"

module Teneo
  module Workflow
    module Base
      module Logging
        include Teneo::Logger

        def message(*args, message:, severity:, application: nil, subject: nil)
          item = self if self.is_a?(Teneo::Workflow::WorkItem)
          item ||= subject if subject.is_a?(Teneo::Workflow::WorkItem)
          item ||= args.shift if args&.first&.is_a?(Teneo::Workflow::WorkItem) || args&.first&.is_a?(Teneo::Workflow::Job)
          task = self if self.is_a?(Teneo::Workflow::Task)
          task ||= application if application.is_a?(Teneo::Workflow::Task)
          task ||= args.shift if args&.first&.is_a?(Teneo::Workflow::Task)
          Teneo::Workflow.config.message_log.add_log_entry(*args, message: message, severity: severity, item: item, task: task)
          application ||= task&.namepath
          subject ||= item&.namepath || item&.name || item&.to_s
          super(*args, message: message, severity: severity, application: application, subject: subject)
        end

        def logger(task = nil)
          task ||= self if self.is_a?(Teneo::Workflow::Task)
          item = self if self.is_a?(Teneo::Workflow::WorkItem)
          run = task&.run || item&.job&.last_run
          run&.logger || super()
        end
      end
    end
  end
end
