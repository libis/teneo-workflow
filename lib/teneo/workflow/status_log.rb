# frozen_string_literal: true

module Teneo
  module Workflow
    module StatusLog

      ### Methods that need implementation in the including class
      # getter accessors for:
      # - status
      # - run
      # - task
      # - item
      # class methods:
      # - create_status(...)
      # - find_last(...)
      # - find_all(...)
      # instance methods:
      # - update_status(...)

      module Classmethods
        def set_status(status: nil, task:, item: nil, progress: nil, max: nil)
          item = nil unless item.is_a? Teneo::Workflow::WorkItem
          entry = find_last(task: task, item: item)
          values = { status: status, task: task, item: item, progress: progress, max: max }.compact
          return create_status(values) if entry.nil?
          return create_status(values) if Base::StatusEnum.to_int(status) < Base::StatusEnum.to_int(entry.status)

          entry.update_status(values.slice(:status, :progress, :max))
        end

        def sanitize(run: nil, task: nil, item: nil)
          if task.is_a?(Teneo::Workflow::Task)
            run ||= task.run
            task = task.namepath
          end
          item = nil unless item.is_a? Teneo::Workflow::WorkItem
          [run, task, item]
        end

        def find_all_last(item)
          list = find_all(item: item)
          list.reverse.uniq(&:task).reverse
        end
      end

      def self.included(base)
        base.extend Classmethods
      end

      def status_sym
        Teneo::Workflow::Base::StatusEnum.to_sym(status)
      end

      def status_txt
        Teneo::Workflow::Base::StatusEnum.to_str(status)
      end
    end
  end
end
