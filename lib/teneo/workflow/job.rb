# frozen_string_literal: true

require "teneo/tools/extensions/hash"

require_relative 'base/logging'
require_relative 'base/status'

# This is the base module for Jobs.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the Job. The name will be used to identify the job. Each time a job is executed,
#     a Run will be created for the associated workflow. The Run will get a name that starts with the job name
#     and ends with the date and time the Run was first started. As such this name attribute serves as an
#     identifier and should be treated as such. If possible it should be unique.
# - workflow: [Object] the workflow that has access to the tasks that need to run.
#
# A minimal in-memory implementation could be:
#
# class Job
#   include ::Teneo::Workflow::Job
#
#   attr_accessor :name, :workflow
#
#   def initialize
#     @name = ''
#     @workflow = ::Teneo::Workflow::Workflow.new
#   end
#
# end
#
module Teneo
  module Workflow
    module Job

      def self.included(klass)
        klass.include(Teneo::Workflow::Base::Logging)
        klass.include(Teneo::Workflow::Base::Status)
      end

      ### Methods that need implementation in the including class
      # getter and setter accessors for:
      # - name
      # - description
      # - input
      # - tasks
      # getter accessors for:
      # - workflow
      # - runs
      # - items
      # - work_dir
      # instance methods:
      # - << / add_item
      # - item_list
      # - make_run
      # - last_run
      # - save!

      ### Derived methods

      # @param [Array] args extra conguration values for this particular run
      def execute(*args)
        run = args.shift if args.first&.is_a?(Teneo::Workflow::Run)
        run ||= make_run(*args)
        raise "Could not create run" unless run
        prepare(run, *args)
        perform(run, *args)
        finish(run, *args)
        run
      end

      def configure(input: {})
        self.input = input
      end

      def prepare(run, *args)
        run.options = workflow.prepare_input(self.input)
        run.configure_tasks(workflow.tasks)
      end

      def perform(run, *args)
        opts = args.last.is_a?(Hash) ? args.last : {}
        run.execute (opts[:action] || :start), *args
      end

      def finish(_run, *_args)
      end

      def tasks
        workflow.tasks
      end

      def size
        items.size
      end

      def run_name(timestamp = Time.now)
        "#{name}-#{timestamp.strftime("%Y%m%d%H%M%S")}"
      end

      def names
        []
      end

      def namepath
        name
      end

      def labels
        []
      end

      def to_dir
        work_dir
      end

      def job
        self
      end

      def status_log
        Teneo::Workflow.config.status_log.find_all(item: self)
      end

      def last_status_log(task = nil)
        task = task.namepath if task.is_a?(Teneo::Workflow::Task)
        Teneo::Workflow.config.status_log.find_last(task: task, item: self)
      end

      def last_status(task)
        last_status_log(task)&.status_sym || Teneo::Workflow::Base::StatusEnum.keys.first
      end

      def run
        last_run
      end
    end
  end
end
