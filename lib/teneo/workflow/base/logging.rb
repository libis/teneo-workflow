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
        include Teneo::Tools::Logger

        class Formatter < Teneo::Tools::Logger::Formatter
          def task_name
            log.payload? ? "#{log.payload.delete(:task_name)} -" : nil
          end

          def item_name
            log.payload? ? "#{log.payload(:item_name)} :" : nil
          end

          def message
            ["--", task_name, item_name, log.message].compact.join(" ")
          end
        end

        def logger_name
          self.run.name
        end

        def add_appender(**appender, &block)
          super(**appender, formatter: Teneo::Workflow::Base::Logging::Formatter.new, &block)
        end

        def trace(message, *args, **opts)
          info = parse_message(message, *args, severity: :trace, **opts)
          logger.trace(message: info[:message], **opts)
          to_message_log(**info)
        end

        def debug(message, *args, **opts)
          info = parse_message(message, *args, severity: :debug, **opts)
          logger.debug(message: info[:message], **opts)
          to_message_log(**info)
        end

        def info(message, *args, **opts)
          info = parse_message(message, *args, severity: :info, **opts)
          logger.info(message: info[:message], **opts)
          to_message_log(**info)
        end

        def warn(message, *args, **opts)
          info = parse_message(message, *args, severity: :warn, **opts)
          logger.warn(message: info[:message], **opts)
          to_message_log(**info)
        end

        def error(message, *args, **opts)
          info = parse_message(message, *args, severity: :error, **opts)
          logger.error(message: info[:message], **opts)
          to_message_log(**info)
        end

        def fatal_error(message, *args, **opts)
          info = parse_message(message, *args, severity: :fatal, **opts)
          logger.fatal(message: info[:message], **opts)
          to_message_log(**info)
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

        protected

        def parse_message(message, *args, severity:, item: nil, task: nil, run: nil, **)
          item = item&.is_a?(Teneo::Workflow::WorkItem) ? item : nil
          item ||= self if self.is_a?(Teneo::Workflow::WorkItem)
          item ||= args.shift if args.first&.is_a?(Teneo::Workflow::WorkItem) || args.first&.is_a?(Teneo::Workflow::Job)
          task = task&.is_a?(Teneo::Workflow::Task) ? task : nil
          task ||= self if self.is_a?(Teneo::Workflow::Task)
          task ||= args.shift if args.first&.is_a?(Teneo::Workflow::Task)
          run = run&.is_a?(Teneo::Workflow::Run) ? item : nil
          run ||= task&.run
          message = (message % args rescue "#{message}#{args.empty? ? "" : " - #{args}"}")
          {
            item: item,
            task: task,
            run: run,
            message: message,
            severity: severity,
            task_name: task&.namepath,
            item_name: item&.namepath || run&.name,
          }
        end

        PARAM_KEYS = [:message, :severity, :item, :task, :run]
        REJECT_KEYS = [:task_name, :item_name]

        def to_message_log(**info)
          params, data = info.except(*REJECT_KEYS).partition { |k, v| PARAM_KEYS.include?(k) }
          Teneo::Workflow.config.message_log.add_entry(data: Hash[data], **Hash[params])
        end
      end
    end
  end
end
