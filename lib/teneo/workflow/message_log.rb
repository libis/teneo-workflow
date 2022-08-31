# frozen_string_literal: true

require "teneo/logger"

module Teneo
  module Workflow
    module MessageLog

      module ClassMethods
        def add_log_entry(*args, message:, severity:, item:, task:)
          message = (message % args rescue "#{message}#{args.empty? ? "" : " - #{args}"}")
          message, *stack_trace = message.split("\n")
          item = item.is_a?(Teneo::Workflow::WorkItem) ? item : nil
          task = task.is_a?(Teneo::Workflow::Task) ? task : nil
          run = task&.run
          info = {
            severity: severity&.to_s,
            item: item,
            run: run,
            task: task&.namepath,
            message: message,
            data: {
              item_name: (item || run.job).namepath,
              stack_trace: stack_trace.empty? ? nil : stack_trace,
            }.compact,
          }
          add_entry(**info)
        end

        # To implement:
        def add_entry(severity:, item:, run:, task:, message:, data: {})
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end
    end
  end
end
