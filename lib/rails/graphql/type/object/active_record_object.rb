# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL Active Record ObjectType
      #
      # The base class for any +ActiveRecord::Base+ class represented as an
      # GraphQL object type
      class Object::ActiveRecordObject < Object::AssignedObject
        self.abstract = true

        # AR objects can be owned by a source
        class_attribute :owner, instance_writer: false

        class << self
          # This class will be able to be resolved from a query point of view if
          # all the requested fields (which are non-object) can also be resolved
          # from active record
          def from_ar?(ar_object, list)
            Array.wrap(list).select do |field_name|
              self[field_name].from_ar?(ar_object)
            end
          end

          # Build the query based on the given +ar_object+ and the +list+ of
          # fields, then run and return the result without passing through
          # ActiveRecord
          def from_ar(ar_object, list)
            # Turn the list of fields into valid arel projections
            list = list.map do |field_name|
              self[field_name].from_ar(ar_object).presence || break
            end

            # If for some reason the list is nil, it means that one of the
            # fields couldn't be resolved from ar
            return if list.nil?

            # Include the primary key and replace the projection to make sure
            # that no other selected field will be loaded
            list.unshift(ar_object.arel_attribute(ar_object.primary_key))

            query = ar_object.arel
            query.projections = list

            # Use the ar_object connection to get the result of the query
            ar_object.connection.select_all(query, query_log_name)
          end

          protected

            # Get the name for log when loading records using queries
            def query_log_name
              @query_log_name ||= format('GraphQL %s Load', name.remove_prefix('GraphQL::'))
            end
        end

        private

          def respond_to_missing?(method_name, include_private = false) # :nodoc:
            owner.new.respond_to?(method_name, include_private) || super
          end

          def method_missing(method_name, *args, **xargs, &block) # :nodoc:
            event.on_instance(owner) do |obj|
              obj.public_send(method_name, *args, **xargs, &block)
            end
          end
      end
    end
  end
end
