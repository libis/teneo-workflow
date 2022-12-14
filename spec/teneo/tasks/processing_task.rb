require "teneo/workflow"

class ProcessingTask < ::Teneo::Workflow::Task
  parameter config: "success", constraint: %w[success async_halt fail error abort],
    description: "determines the outcome of the processing"

  def process(item)
    return unless item.is_a? TestFileItem

    case parameter(:config).downcase.to_sym
    when :success
      info "Task success"
    when :async_halt
      set_status(item, :ASYNC_HALT)
      error "Task failed with async_halt status"
    when :fail
      set_status(item, :FAILED)
      error "Task failed with failed status"
    when :error
      raise Libis::Workflow::Error, "Task failed with WorkflowError exception"
    when :abort
      raise Libis::Workflow::Abort, "Task failed with WorkflowAbort exception"
    else
      info "Task success"
    end
  end
end
