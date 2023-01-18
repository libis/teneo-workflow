# frozen_string_literal: true

require "teneo/workflow/file_item"

class TestFileItem
  include Teneo::Workflow::FileItem

  attr_accessor :name, :label, :parent
  attr_reader :items, :options, :properties

  def initialize
    @items = []
    @options = {}
    @properties = {}
    @name = ''
    @label = ''
    @parent = nil
  end

  def save!
  end

  def <<(item)
  end

  alias add_item <<

  def item_list
    @items
  end

  def filename=(file)
    raise "'#{file}' is not a file" unless File.file? file
    super file
  end

end
