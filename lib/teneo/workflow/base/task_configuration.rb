# frozen_string_literal: true

module Teneo
  module Workflow
    module Base
      module TaskConfiguration
        def configure(parameter_values)
          parameter_values.each do |name, value|
            parameter(name.to_sym, value)
          end if parameter_values
        end
      end
    end
  end
end
