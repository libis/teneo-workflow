# frozen_string_literal: true

require 'teneo/workflow/message_registry'

module Teneo
  module Workflow
    module Base
      module Logging

        # Add a structured message to the log history.
        #
        # The message text will be passed to the % operator with the args parameter.
        # If that failes (e.g. because the format string is not correct) the args value is appended to the message.
        #
        # @param [Symbol] severity message level
        # @param [String] message the message text to be logged
        # @param [String] task the hierarchical name of the current task
        # @param [Array] args string format values
        def log_message(:severity, :message, :task, *args)
          message ||= ''
          task = task || ''
          message_text = message % args rescue "#{message} - #{args}"
          add_log severity: severity, text: message_text, task: task
        end

        # Helper function for the WorkItems to add a log entry to the log_history.
        #
        # @param [Symbol] severity message level
        # @param [String] message the message text to be logged
        # @param [String] task the hierarchical name of the current task
        def add_log(:severity, :text, :task)
          msg = message_struct(message)
          add_log_entry(msg)
          save!
        end

        def <=(message = {})
          add_log(message)
        end

        protected

        # create and return a proper message structure
        # @param [Hash] opts
        def message_struct(opts = {})
          opts.reverse_merge!(severity: :info, code: nil, text: '')
          {
            severity: ::Logging.levelify(opts[:severity]).upcase,
            task: opts[:task],
            code: opts[:code],
            message: opts[:text],
          }.cleanup
        end
      end
    end
  end
end
