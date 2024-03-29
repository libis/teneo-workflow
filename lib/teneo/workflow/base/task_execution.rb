# frozen_string_literal: true

module Teneo
  module Workflow
    module Base
      module TaskExecution
        def action
          parent&.action.to_s
        end

        def action=(value)
          parent&.action = value.to_s
        end

        def execute(item, *args)
          return item if action == "abort" && !run_always

          item = execution_loop(item, *args)

          self.action = "abort" unless item
          item
        rescue Teneo::Workflow::Error => e
          error e.message, item
          set_status :failed, item: item
        rescue Teneo::Workflow::Abort => e
          set_status :failed, item: item
          raise e if parent
        rescue Exception => e
          set_status :failed, item: item
          fatal "Exception occured: #{e.message} @ #{e.backtrace.first}", item
          debug e.backtrace.join("\n")
        end

        def pre_process(_item, *_args)
          true
          # optional implementation
        end

        def post_process(_item, *_args)
          # optional implementation
        end

        protected

        def execution_loop(item, *args)
          (retry_count.abs + 1).times do
            new_item = process_item(item, *args)
            item = new_item if check_item_type item, raise_on_error: false

            case get_status(item: item)
            when :not_started
              return item
            when :done, :reverted
              return item
            when :failed, :async_halt
              self.action = "abort" if abort_on_failure
              return item
            when :async_wait
              sleep(retry_interval)
            else
              warn "Something went terribly wrong, retrying ..."
            end
          end
          item
        end

        def process_item(item, *args)
          return item if get_status(item: item) == :done && !run_always

          if pre_process(item, *args)
            set_status :started, item: item
            process item, *args
          end

          run_subitems(item, *args) if recursive
          set_status(:done, item: item) if status_equals(:started, item: item)

          post_process item, *args

          item
        end

        def capture_cmd(cmd, *opts)
          out = StringIO.new
          err = StringIO.new
          $stdout = out
          $stderr = err
          status = system cmd, *opts
          [status, out.string, err.string]
        ensure
          $stdout = STDOUT
          $stderr = STDERR
        end
      end
    end
  end
end
