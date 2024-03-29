# frozen_string_literal: true

require 'teneo/tools/extensions/hash'

require_relative 'base/logging'
require_relative 'base/status'

module Teneo
  module Workflow
    # Base module for all work items.
    #
    # This module lacks the implementation for the data attributes. It functions as an interface that describes the
    # common functionality regardless of the storage implementation. These attributes require some implementation:
    #
    # - name: [String] the name of the object
    # - label: [String] the label of the object
    # - parent: [Object|nil] a link to a parent work item. Work items can be organized in any hierarchy you think is
    #     relevant for your workflow (e.g. directory[/directory...]/file/line or library/section/book/page). Of course
    #     hierarchies are not mandatory.
    # - items: [Enumerable] a list of child work items. see above.
    # - options: [Hash] a set of options for the task chain on how to deal with this work item. This attribute can be
    #     used to fine-tune the behaviour of tasks that support this.
    # - properties: [Hash] a set of properties, typically collected during the workflow processing and used to store
    #     final or intermediate resulst of tasks.
    #
    # The module is created so that it is possible to implement an ActiveRecord/Datamapper/... implementation easily.
    # A simple in-memory implementation would require:
    #
    # attr_accessor :parent
    # attr_accessor :items
    # attr_accessor :options, :properties
    # attr_accessor :summary
    #
    # def initialize
    #   self.parent = nil
    #   self.items = []
    #   self.options = {}
    #   self.properties = {}
    # end
    #
    # The implementation should also take care that the public methods #save and #save! are implemented.
    # ActiveRecord and Mongoid are known to implement these, but others may not.
    #
    module WorkItem

      def self.included(klass)
        klass.include(Teneo::Workflow::Base::Logging)
        klass.include(Teneo::Workflow::Base::Status)
      end

      ### Methods that need implementation:
      # getter and setter accessors for:
      # - name
      # - label
      # - parent
      # getter accessors for:
      # - items
      # - options
      # - properties
      # instance methods:
      # - save!
      # - <<
      # - item_list

      ### Derived methods. Should work as is when required methods are implemented properly

      def to_s
        name
      end

      def work_dir
        file_safe_name
      end

      def work_path
        File.join((parents << self).map(&:work_dir).cleanup)
      end

      def parents
        (parent&.parents || []).push(parent).compact
      end

      def names
        (parent&.names || []).push(name).compact
      end

      def namepath
        names.join('/')
      end

      def labels
        (parent&.labels || []).push(label).compact
      end

      def labelpath
        labels.join('/')
      end

      def short_name
        to_s.gsub(/[^\w\s._-]/, '').split(/[\s._-]+/).map(&:capitalize).join
      end

      # Safe version of the to_s output.
      #
      # @return [String] safe string
      def safe_name
        to_s.gsub(/[^\w.-]/) { |s| format('%<prefix>s%<ord>02x', prefix: '%', ord: s.ord) }
      end

      # Filename safe version of the to_s output.
      #
      # @return [String] filename safe string
      def file_safe_name
        to_s.gsub(/[$:!&]/, '')
      end

      # Iterates over the work item clients and invokes code on each of them.
      def each(&block)
        items.each(&block)
      end

      def size
        items.size
      end

      alias count size

      def status_log
        Teneo::Workflow.config.status_log.find_all(item: self)
      end

      # @return [WorkItem] the root WorkItem object
      def root_item
        parent&.is_a?(WorkItem) ? parent.root_item : self
      end

      def job
        parent&.job
      end

      def run
        job.run
      end

    end
  end
end
