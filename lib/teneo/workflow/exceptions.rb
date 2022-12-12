# frozen_string_literal: true

module Teneo
  module Workflow
    class Error < ::RuntimeError
    end

    class Abort < ::RuntimeError
    end
  end
end
