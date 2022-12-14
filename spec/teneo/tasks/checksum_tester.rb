require "teneo/workflow"

require "teneo/tools/checksum"

class ChecksumTester < ::Teneo::Workflow::Task
  parameter checksum_type: nil,
    description: "Checksum type to use.",
    constraint: ::Teneo::Tools::Checksum::CHECKSUM_TYPES.map { |x| x.to_s }

  def process(item)
    return unless item.is_a? TestFileItem

    checksum_type = parameter(:checksum_type)

    if checksum_type.nil?
      ::Teneo::Tools::Checksum::CHECKSUM_TYPES.each do |x|
        test_checksum(item, x) if item.checksum(x)
      end
    else
      test_checksum(item, checksum_type)
    end
  end

  def test_checksum(item, checksum_type)
    checksum = ::Teneo::Tools::Checksum.hexdigest(item.fullpath, checksum_type.to_sym)
    return if item.checksum(checksum_type) == checksum
    raise ::Teneo::Workflow::Error, "Checksum test #{checksum_type} failed for #{item.filepath}"
  end
end
