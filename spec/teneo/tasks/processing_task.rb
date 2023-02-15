require "teneo/workflow"

class ProcessingTask < ::Teneo::Workflow::Task
  parameter config: "success", constraint: %w[success async_halt fail error abort],
    description: "determines the outcome of the processing"

  def process(item)
    return unless item.is_a? TestFileItem

    case parameter(:config).downcase.to_sym
    when :success
      info "Task success", item
    when :async_halt
      set_status(:async_halt, item: item)
      error "Task aborted with async_halt status", item
    when :fail
      set_status(:failed, item: item)
      error "Task aborted with failed status", item
    when :error
      raise Teneo::Workflow::Error, "Task aborted with WorkflowError exception"
    when :abort
      raise Teneo::Workflow::Abort, "Task aborted with WorkflowAbort exception"
    else
      info "Task success", item
    end
  end
end
