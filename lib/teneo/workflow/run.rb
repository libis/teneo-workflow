# frozen_string_literal: true

require 'fileutils'

require_relative 'base/logging'

# Base module for all workflow runs. It is created by job when the job is executed.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the Run
# - start_date: [Time] the timestamp of the execution of the run
# - job: [Object] a reference to the Job this Run belongs to
#
module Teneo
  module Workflow
    module Run

      def self.included(klass)
        klass.include Teneo::Workflow::Base::Logging
      end

      ### Methods that need implementation in the including class
      # getter and setter accessors for:
      # - name
      # - config
      # getter accessors for:
      # - job
      # - options
      # - properties
      # instance methods:
      # - save!

      ### Derived methods

      def runner
        @runner ||= Teneo::Workflow::TaskRunner.new(self, **config)
      end

      def action
        properties[:action]
      end

      def action=(value)
        properties[:action] = value.to_s
      end

      def configure_tasks(tasks)
        config[:tasks] = tasks
      end

      # Execute the workflow.
      def execute(action = 'start', *args)
        properties[:action] = action
        save!
        runner.execute(job, *args)
      end

      def status_log
        Teneo::Workflow.config.status_log.find_all(run: self, item: self.job)
      end

      def last_status(item = nil, task: runner.namepath)
        Teneo::Workflow.config.status_log.find_last(run: self, task: task, item: item)&.status_sym || Teneo::Workflow::Base::StatusEnum.keys.first
      end

      def items
        job.items
      end

      def size
        job.size
      end

      def run
        self
      end

    end
  end
end
