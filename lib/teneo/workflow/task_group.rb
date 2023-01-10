# frozen_string_literal: true

require_relative 'task'

module Teneo
  module Workflow
    class TaskGroup < Task
      attr_accessor :tasks, :name, :subtasks_stopper

      recursive false

      def initialize(parent, **cfg)
        @tasks = []
        @name = cfg[:name]
        @subtasks_stopper = false
        super
        configure_tasks(cfg[:tasks])
      end

      def add_task(task)
        @tasks << task
        task.parent = self
      end

      alias << add_task

      def configure_tasks(tasks, *args)
        (tasks || []).each do |task|
          task[:class] ||= 'Teneo::Workflow::TaskGroup'
          task_obj = task[:class].constantize.new(self, **task)
          self << task_obj
        end
      end

      protected

      def process(item, *args)
        return unless check_processing_subtasks

        tasks = subtasks
        return if tasks.empty?

        status_count = Hash.new(0)
        status_progress(0, max: tasks.count, item: item)
        continue = true
        tasks.each_with_index do |task, i|
          break if task.properties[:autorun] == false
          unless task.run_always
            next unless continue

            if last_status(item: item) == :done
              debug 'Retry: skipping task %s because it has finished successfully.', item, task.namepath
              next
            end
          end
          info 'Running subtask (%d/%d): %s', item, i + 1, tasks.size, task.name
          new_item = task.execute item, *args
          item = new_item if new_item.is_a?(Teneo::Workflow::WorkItem)
          status_progress(i + 1, item: item)
          item_status = get_status(task: task, item: item)
          status_count[item_status] += 1
          if Base::StatusEnum.failed?(item_status)
            continue = false
            break if abort_on_failure
          end
        end

        substatus_check(status_count, item, 'task')

        info get_status_txt(item: item).capitalize, item
      end

      def stop_processing_subtasks
        @subtasks_stopper = true
      end

      def check_processing_subtasks
        if @subtasks_stopper
          @subtasks_stopper = false
          return false
        end
        true
      end

      def subtasks
        tasks
      end
    end
  end
end
