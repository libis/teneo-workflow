# frozen_string_literal: true

require "teneo/workflow/status_log"

TestStatusLog = Struct.new(:status, :progress, :max, :created_at, :updated_at, keyword_init: true) do
  include Teneo::Workflow::StatusLog

  def initialize(status: nil, progress: nil, max: nil)
    t = Time.now
    super status: status, progress: progress, max: max, created_at: t, updated_at: t
  end

  def update_status(status: nil, progress: nil, max: nil)
    self.status = status if status
    self.progress = progress if progress
    self.max = max if max
    self.updated_at = Time.now
  end

  def self.status_list
    @status_list ||= {}
  end

  def self.create_status(**info)
    key, info = parse_info(**info)
    entry = new(**info)
    status_list[key] = entry
    key.merge(entry.to_h)
  end

  def self.find_entry(run: nil, task: nil, item: nil)
    key, _ = parse_info(run: run, task: task, item: item)
    status_list[key]
  end

  def self.find_all(**info)
    to_a(status_list.select do |k, v|
      info.keys.all? { |key| k[key] == info[key] }
    end)
  end

  # def self.find_last
  # end

  def self.clear!
    @status_list = {}
  end

  def self.parse_info(**info)
    run = info.delete(:run)
    task = info.delete(:task)
    item = info.delete(:item)
    run ||= task.is_a?(Teneo::Workflow::Task) ? task.run : nil
    task = task.is_a?(Teneo::Workflow::Task) ? task.namepath : task
    key = {run: run, task: task, item: item}
    [key, info]
  end

  def self.to_a(h = nil)
    h ||= status_list
    h.map do |k, v|
      x = k.merge(v.to_h)
      x[:run] = x[:run]&.name
      x[:item] = x[:item]&.namepath
      x
    end
  end

  def self.ai(options = {})
    to_a.ai(options)
  end
end
