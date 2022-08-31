# frozen_string_literal: true

module Teneo
  module Workflow
    module StatusLog

      ### Methods that need implementation in the including class
      # getter accessors for:
      # - status
      # class methods:
      # - create_status(...)
      # - find_last(...)
      # - find_all(...)
      # instance methods:
      # - update_status(...)

      module ClassMethods
        def set_status(status: nil, run:, task:, item: nil, progress: nil, max: nil)
          entry = find_last(run: run, task: task, item: item)
          values = { status: status, run: run, task: task, item: item, progress: progress, max: max }.compact

          return create_status(**values) if entry.nil?
          return create_status(**values) if Base::StatusEnum.to_int(status) < Base::StatusEnum.to_int(entry.status)

          entry.update_status(**(values.slice(:status, :progress, :max)))
        end

        # To implement:
        def create_status(**info)
        end

        # To implement:
        def find_last(**info)
          nil
        end

        # To implement:
        def find_all(**info)
          []
        end

        # To implement:
        def find_all_last(**info)
          []
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      def status_sym
        Teneo::Workflow::Base::StatusEnum.to_sym(status)
      end

      def status_txt
        Teneo::Workflow::Base::StatusEnum.to_str(status)
      end

      # To implement:
      def update_status(status:, progress:, max:)
      end
    end
  end
end
