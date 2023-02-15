# frozen_string_literal: true

require 'teneo/tools/parameter'

module Teneo
  module Workflow
    module Base
      module TaskConfiguration

        def self.included(klass)
          klass.include ::Teneo::Tools::Parameter::Container
        end

        def configure(parameter_values)
          (parameter_values || {}).each do |name, value|
            case name.to_sym
            when :abort_on_failure
              self.class.abort_on_failure(value)
            when :retry_count
              self.class.retry_count(value)
            when :retry_interval
              self.class.retry_interval(value)
            when :run_always
              self.class.run_always(value)
            when :recursive
              self.class.recursive(value)
            else
              parameter(name.to_sym, value)
            end
          end if parameter_values
        end
      end
    end
  end
end
