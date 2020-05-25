# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Core
      ##
      # :singleton-method:
      #
      # Accepts a logger conforming to the interface of Log4r which is then
      # passed on to any graphql operation which can be retrieved on both a class
      # and instance level by calling +logger+.
      mattr_accessor :logger, instance_writer: false

      ##
      # :singleton-method:
      # Specifies if the results of operations should be encoded with
      # +ActiveSupport::JSON.encode+ instead of the default +JSON.generate+.
      #
      # See also https://github.com/rails/rails/blob/master/activesupport/lib/active_support/json/encoding.rb
      mattr_accessor :encode_with_active_support, instance_writer: false, default: false

      ##
      # Set specific configurations for GraphiQL portion of the gem. You can
      # disable it by passing a false value.
      #
      # +config+ Either +false+ to disable or a +Hash+ with further settings
      def self.graphiql=(config)
        return unless config.present?

        GraphiQL.enabled = true
        config.try(:each) { |k, v| GraphiQL.send "#{k}=", v }
      end
    end
  end
end