# frozen_string_literal: true

require "teneo/workflow/file_item"

class TestFileItem
  include Teneo::Workflow::FileItem

  def filename=(file)
    raise "'#{file}' is not a file" unless File.file? file
    set_checksum :SHA256, ::Libis::Tools::Checksum.hexdigest(file, :SHA256)
    super file
  end

  def name
    properties[:name] || super
  end
end
