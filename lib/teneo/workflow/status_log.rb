# frozen_string_literal: true

module Teneo
  module Workflow
    module StatusLog
      ### This module should be included in a new class where missing methods are implemented
      # The new class will have both class methods and instance methods.
      # The class is a factory class where the class methods support creating, updating and finding
      # log entries, while the class instances are the log entries themselves.
      # This resembles the ActiveRecord pattern used by Rails.

      ### Instance methods that need implementation in the including class
      # getter and setter accessors for:
      # - status
      # - progress
      # - max
      # - created_at (optional, but may be needed for reporting)
      # - updated_at (optional, but may be needed for reporting)
      # instance methods:
      # - update
      # - save!

      # To implement:
      def update_status(status: nil, progress: nil, max: nil)
        raise Teneo::WorkflowAbort.new "Method not implemented"
      end

      # To implement:
      def save!
        raise Teneo::WorkflowAbort.new "Method not implemented"
      end

      # Derived methods:

      def status_sym
        Teneo::Workflow::Base::StatusEnum.to_sym(status)
      end

      def status_txt
        Teneo::Workflow::Base::StatusEnum.to_str(status)
      end

      module ClassMethods
        ### Class methods that need implementation in the including class
        # class methods:
        # - create_status(...)
        # - find_entry(...)
        # - find_all(...)

        def set_status(status:, run: nil, task: nil, item: nil, progress: nil, max: nil)

          # make sure we have a run
          run ||= task.is_a?(Teneo::Workflow::Task) ? task.run : nil
          unless run
            raise Teneo::WorkflowAbort.new "Status log cannot be created: no run info"
          end

          # Updates to status or progress should overwrite existing log entries.
          if entry = find_entry(run: run, task: task, item: item)
            return entry.update_status(status: status, progress: progress, max: max)
          end

          create_status(run: run, task: task, item: item, status: status, progress: progress, max: max)
        end

        # To implement:
        def create_status(run:, task:, item: nil, status: nil, progress: nil, max: nil)
          raise Teneo::Workflow::Abort.new "Method not implemented"
        end

        # To implement:
        def find_entry(run:, task:, item:)
          raise Teneo::Workflow::Abort.new "Method not implemented"
        end

        # To implement:
        def find_all(**info)
          raise Teneo::Workflow::Abort.new "Method not implemented"
        end

        def find_last(**info)
          raise Teneo::Workflow::Abort.new "Method not implemented"
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end
    end
  end
end
