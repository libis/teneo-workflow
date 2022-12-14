# frozen_string_literal: true

require "teneo/tools/parameter"
require "teneo/workflow/task_group"
require "teneo/tools/extensions/hash"

# This is the base module for Workflows.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the Workflow. The name will be used to identify the workflow. Each time a workflow
#     is executed, a Run will be created. The Run will get a name that starts with the workflow name and ends with
#     the date and time the Run was started. As such this name attribute serves as an identifier and should be
#     treated as such. If possible is should be unique.
# - description: [String] more information about the workflow.
# - config: [Hash] detailed configuration for the workflow. The application assumes it behaves as a Hash and will
#     access it with [], merge! and delete methods. If your implementation decides to implement it with another
#     object, it should implement above methods. The config Hash requires the following keys:
#   - input: [Hash] all input parameter definitions where the key is the parameter name and the value is another
#       Hash with arguments for the parameter definition. It typically contains the following arguments:
#       - default: default value if no value specified when the workflow is executed
#       - propagate_to: the task name (or path) and parameter name that any set value for this parameter will be
#           propagated to. The syntax is <task name|task path>[#<parameter name>]. If the #<parameter name> part
#           is not present, the same name as the input parameter is used. If you want to push the value to
#           multiple task parameters, you can either supply an array of propagate paths or put them in a string
#           separated by a ','.
#   - tasks: [Array] task definitions that define the order in which the tasks should be executed for the workflow.
#       A task definition is a Hash with the following values:
#       - class: [String] the class name of the task including the module names
#       - name: [String] optional if class is present. A friendly name for the task that will be used in the logs.
#       - tasks: [Array] a list of subtask defintions for this task.
#
#       Additionally the task definition Hash may specify values for any other parameter that the task knows of.
#       All tasks have some fixed parameters. For more information about these see the documentation of
#       the task class.
#
#       A task definition does not require to have a 'class' entry. If not present the default
#       ::Teneo::Workflow::TaskGroup class will be instatiated. It will do nothing itself, but will execute the
#       subtasks on the item(s). In such case a 'name' is mandatory.
#
# These values should be set by calling the #configure method which takes a Hash as argument with :name,
# :description, :input and :tasks keys.
#
# A minimal in-memory implementation could be:
#
# class Workflow
#   include ::Teneo::Workflow::Workflow
#
#   attr_accessor :name, :description, :config
#
#   def initialize
#     @name = ''
#     @description = ''
#     @config = Hash.new
#   end
#
# end
#
module Teneo
  module Workflow
    module Workflow
      module ClassMethods
        def require_all
          Teneo::Workflow.require_all(Teneo::Workflow.config.itemdir)
          Teneo::Workflow.require_all(Teneo::Workflow.config.taskdir)
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      def configure(input: {}, tasks: [])
        config['input'] = input.deep_
        config['tasks'] = tasks.deep_stringify_keys
        config.merge! cfg

        self.class.require_all

        config
      end

      def input
        config['input'].each_with_object({}) do |input_def, hash|
          name = input_def.first
          default = input_def.last['default']
          parameter = Teneo::Tools::Parameter::Definition.new(name: name, default: default)
          input_def.last.each { |k, v| parameter[k.to_sym] = v }
          hash[name] = parameter
        end
      rescue => _e
        {}
      end

      # @param [Hash] options
      def task_parameters(values, options = {})
        data = values.stringify_keys
        result = options.stringify_keys
        input.each do |key, parameter|
          value = if data.has_key?(key)
            data[key]
          elsif result.has_key?(key)
            value = parameter.parse(result[key])
          elsif !parameter[:default].nil?
            value = parameter[:default]
          else
            nil
          end
          propagate_to = parameter[:propagate_to]
          propagate_to = case propagate_to
          when Array
            propagate_to
          when String
            propagate_to.split(/[\s,;]+/)
          else
            []
          end
          propagate_to = propagate_to.map do |obj|
            if obj.is_a?(String)
              task_name, param_name = obj.split("#")
              obj = {
                task: task_name,
                parameter: param_name
              }
            end
            obj[:parameter] ||=  key.to_s
            obj
          end
          result[key] = value if propagate_to.empty?
          propagate_to.each do |target|
            result[target[:task]] ||= {}
            result[target[:task]][:parameters] ||= {}
            result[task_name][target[:parameter]] = value
          end
        end
        result
      end

      def tasks(parent = nil)
        config["tasks"]
      end

      def instantize_task(parent, cfg)
        task_class = Teneo::Workflow::TaskGroup
        task_class = cfg["class"].constantize if cfg["class"]
        # noinspection RubyArgCount
        task_instance = task_class.new(parent, cfg)
        cfg["tasks"]&.map do |task_cfg|
          task_instance << instantize_task(task_instance, task_cfg)
        end
        task_instance
      end
    end
  end
end
