# frozen_string_literal: true

require_relative "test_file_item"

class TestDirItem
  include Teneo::Workflow::FileItem

  attr_accessor :name, :label, :parent
  attr_reader :items, :options, :properties

  def initialize
    @items = []
    @options = {}
    @properties = {}
    @name = ""
    @label = ""
    @parent = nil
  end

  def save!
  end

  def <<(item)
    @items << item
    item.parent = self
  end

  alias_method :add_item, :<<

  def item_list
    @items
  end

  def filename=(dir)
    raise "'#{dir}' is not a directory" unless File.directory? dir
    super dir
  end
end
