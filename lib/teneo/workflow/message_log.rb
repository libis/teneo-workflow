# frozen_string_literal: true

require "teneo/tools/logger"

module Teneo
  module Workflow
    module MessageLog
      module ClassMethods
        # To implement:
        def add_entry(severity:, item:, task:, run:, message:, **data)
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end
    end
  end
end
