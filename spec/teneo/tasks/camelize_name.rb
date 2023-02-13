require "teneo/workflow"

require "teneo/tools/extensions/string"

class CamelizeName < ::Teneo::Workflow::Task
  def process(item)
    return unless item.is_a?(TestFileItem) || item.is_a?(TestDirItem)
    item.name = item.name.camelize
  end
end
