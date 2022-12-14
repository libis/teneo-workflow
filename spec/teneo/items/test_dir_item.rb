# frozen_string_literal: true

require "teneo/workflow/file_item"

class TestDirItem
  include Teneo::Workflow::FileItem

  def name=(dir)
    raise "'#{dir}' is not a directory" unless File.directory? dir
    super dir
  end

  def name
    properties[:name] || super
  end
end
