# frozen_string_literal: true

require_relative "status_enum"

module Teneo
  module Workflow
    module Base
      module Status

        # Assumes that a StatusLog implementation class is set in Teneo::Workflow.config.status_log

        # @return [Teneo::Workflow::Status] newly created status entry
        def set_status(status, run: nil, task: nil, item: nil, progress: nil, max: nil)
          info = resolve_info(run: run, task: task, item: item)
          Teneo::Workflow.config.status_log.set_status(status: status, progress: progress, max: max, **info)
        end

        # @return [Teneo::Workflow::Status] updated or created status entry
        def status_progress(progress = nil, max: nil, task: nil, item: nil)
          if entry = status_entry(task: task, item: item)
            entry.update_status(**{ progress: progress || entry.progress + 1, max: max }.compact)
          else
            set_status(:started, task: task, item: item, progress: progress, max: max)
          end
        end

        # @return [Teneo::Workflow::Status] status entry or nil if not found
        def status_entry(task: nil, item: nil)
          info = resolve_info(task: task, item: item)
          Teneo::Workflow.config.status_log.find_entry(**info)
        end

        # Get last known status symbol for a given task and item
        # @return [Symbol] the status code
        def get_status(task: nil, item: nil)
          entry = status_entry(task: task, item: item)
          entry&.status_sym || Teneo::Workflow::Base::StatusEnum.keys.first
        end

        # Get last known status text for a given task
        # @return [String] the status text
        def get_status_txt(task: nil, item: nil)
          entry = status_entry(task: task, item: item)
          entry&.status_txt || Teneo::Workflow::Base::StatusEnum.values.first
        end

        # Gets the last known status label of the object.
        # @return [String] status label ( = task name + status )
        def get_status_label(task: nil, item: nil)
          "#{task}#{get_status(task: task, item: item).to_s.camelize}"
        end

        # Check status of the object.
        # @return [Boolean] true if the object status matches
        def status_equals(status, task: nil, item: nil)
          compare_status(status, task: task, item: item) == 0
        end

        # Compare status with current status of the object.
        # @return [Integer] 1, 0 or -1 depending on which status is higher in rank
        def compare_status(status, task:, item:)
          Teneo::Workflow::Base::StatusEnum.to_int(get_status(task: task, item: item)) <=> Teneo::Workflow::Base::StatusEnum.to_int(status)
        end

        def resolve_info(run: nil, task: nil, item: nil)
          run ||= self if self.is_a?(Teneo::Workflow::Run)
          task ||= self if self.is_a?(Teneo::Workflow::Task)
          item ||= self if self.is_a?(Teneo::Workflow::WorkItem)
          item ||= self if self.is_a?(Teneo::Workflow::Job)
          if task.is_a?(Teneo::Workflow::Task)
            run ||= task.run
            task = task.namepath
          end
          { run: run, task: task, item: item }
        end
      end
    end
  end
end
