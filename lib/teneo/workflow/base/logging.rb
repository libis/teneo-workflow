# frozen_string_literal: true

require "teneo/tools/logger"

# require_relative "../work_item"
# require_relative "../job"
# require_relative "../task"
# require_relative "../run"

module Teneo
  module Workflow
    module Base
      module Logging

        def self.included(klass)
          klass.include Teneo::Tools::Logger
          klass.include InstanceMethods
        end
        
        module InstanceMethods
          def logger_name
            self.run.name
          end

          def logger
            case self
            when Teneo::Workflow::Run
              super
            when Teneo::Workflow::Task
              self.run&.logger
            when Teneo::Workflow::WorkItem
              self.job&.last_run&.logger
            else
              super
            end
          end

          def build_logger_event(*args, **opts)
            item = opts.delete(:item)
            task = opts.delete(:task)
            run = opts.delete(:run)
            items, args = args.partition {|x| x.is_a?(Teneo::Workflow::WorkItem) || x.is_a?(Teneo::Workflow::Job)}
            item ||= items.first
            tasks, args = args.partition {|x| x.is_a?(Teneo::Workflow::Task)}
            task ||= tasks.first
            runs, args = args.partition { |x| x.is_a?(Teneo::Workflow::Run)}
            run ||= runs.first
            event = super(*args, **opts)
            event = to_message_log(event, item: item, task: task, run: run)
            event
          end
        end
  
        protected

        def parse_message(event, item:, task:, run:)
          item = item&.is_a?(Teneo::Workflow::WorkItem) ? item : nil
          item ||= self if self.is_a?(Teneo::Workflow::WorkItem)
          task = task&.is_a?(Teneo::Workflow::Task) ? task : nil
          task ||= self if self.is_a?(Teneo::Workflow::Task)
          run = run&.is_a?(Teneo::Workflow::Run) ? item : nil
          run ||= task&.run
          message = event.message
          {
            item: item,
            task: task,
            run: run,
            message: message,
            severity: event.severity,
            task_name: task&.namepath,
            item_name: item&.namepath || run&.name,
          }
        end

        PARAM_KEYS = [:message, :severity, :item, :task, :run]
        REJECT_KEYS = [:task_name, :item_name]

        def to_message_log(event, item:, task:, run:)
          info = parse_message(event, item: item, task: task, run: run)
          event.context = "#{info[:task_name]} - #{info[:item_name]}"
          params, data = info.except(*REJECT_KEYS).partition { |k, v| PARAM_KEYS.include?(k) }
          Teneo::Workflow.config.message_log.add_entry(data: Hash[data], **Hash[params])
          event
        end
      end
    end
  end
end
