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
            parameter(name.to_sym, value)
          end if parameter_values
        end
      end
    end
  end
end
