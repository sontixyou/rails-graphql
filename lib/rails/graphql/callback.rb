# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = Rails GraphQL Callback
    #
    # An extra powerfull proc that can handle way more situations than the
    # original block caller
    class Callback
      attr_reader :event_name, :block, :target, :filters

      delegate :event_filters, to: :target
      delegate :callback_inject_arguments, :callback_inject_named_arguments,
        to: '::Rails::GraphQL.config'

      # Directives need to be contextualized by the given instance as +context+
      def self.set_context(item, context)
        lambda { |*args| item.call(*args, context: context) }
      end

      def initialize(target, event_name, *args, **xargs, &block)
        raise ::ArgumentError, <<~MSG.squish if block.nil? && !args.first.present?
          Either provide a block or a method name when setting a #{event_name}
          callback on #{target.inspect}.
        MSG

        if block.nil?
          block = args.shift
          valid_format = block.is_a?(Symbol) || block.is_a?(Proc)
          raise ::ArgumentError, <<~MSG.squish unless valid_format
            The given #{block.class.name} class is not a valid callback.
          MSG
        end

        @target = target
        @event_name = event_name

        @pre_args = args
        @pre_xargs = xargs.slice!(*event_filters.keys)
        @filters = xargs.map do |key, value|
          [key, event_filters[key][:sanitizer]&.call(value) || value]
        end.to_h

        @block = block
      end

      # This does the whole checking and preparation in order to really execute
      # the callback method
      def call(event, context: nil)
        return unless event.name === event_name && can_run?(event)
        block.is_a?(Symbol) ? call_symbol(event) : call_proc(event, context)
      end

      # Get a described source location for the callback
      def source_location
        block.is_a?(Proc) ? block.source_location : [
          "(symbolized-callback/#{target.inspect})",
          block,
        ]
      end

      # This basically allows the class to be passed as +&block+
      def to_proc
        method(:call).to_proc.tap do |block|
          block.define_singleton_method(:source_location, &method(:source_location))
        end
      end

      private

        # Using the filters, check if the current callback can be executed
        def can_run?(event)
          filters.all? { |key, options| event_filters[key][:block].call(options, event) }
        end

        # Call the callback block as a symbol
        def call_symbol(event)
          owner = target.try(:proxied_owner) || target.try(:owner) || target
          event.on_instance(owner) do |instance|
            block = instance.method(@block)
            args, xargs = collect_parameters(event, block)
            block.call(*args, **xargs)
          end
        end

        # Call the callback block as a proc
        def call_proc(event, context = nil)
          args, xargs = collect_parameters(event)
          (context || event).instance_exec(*args, **xargs, &block)
        end

        # Read the arguments needed for a block then collect them from the
        # event and return the execution args
        def collect_parameters(event, block = @block)
          args_source = event.send(:args_source) || event
          start_args = [@pre_args.deep_dup, @pre_xargs.deep_dup]
          return start_args unless inject_arguments?

          # TODO: Maybe we need to turn procs into lambdas so the optional
          # arguments doesn't suffer any kind of change
          idx = -1
          block.parameters.each_with_object(start_args) do |(type, name), result|
            case type
            when :opt, :req
              idx += 1
              next unless callback_inject_arguments
              result[0][idx] ||= event.parameter(name) if event.parameter?(name)
            when :keyreq
              next unless callback_inject_named_arguments
              result[1][name] ||= args_source[name]
            when :key
              next unless callback_inject_named_arguments
              result[1][name] ||= args_source[name] if args_source.key?(name)
            end
          end
        end

        # Check if the callback should inject arguments
        def inject_arguments?
          callback_inject_arguments || callback_inject_named_arguments
        end
    end
  end
end
