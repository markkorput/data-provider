require 'logger'

module DataProvider

  class ProviderMissingException < Exception
  end

  module Base

    def self.included(base)
      base.class_eval do
        include InstanceMethods
        extend ClassMethods
      end
    end

    module ClassMethods
      # provides, when called with a hash param, will define 'simple providers' (providers
      # with a simple, static value). When called without a param (or nil) it returns
      # the current cumulative 'simple providers' hash
      def provides simple_provides = nil
        if simple_provides
          @data_provider ||= {}
          @data_provider[:provides] ||= {}
          @data_provider[:provides].merge!(simple_provides)
          return self
        end
        # no data given? just return existing hash
        (@data_provider || {})[:provides] || {}
      end

      # returns the requested provider as a Provider object
      def get_provider(id)
        args = data_provider_definitions.find{|args| args.first == id}
        return args.nil? ? nil : Provider.new(*args)
      end

      # adds a new provider to the class
      def provider identifier, opts = {}, &block
        add_provider(identifier, opts, block_given? ? block : nil)
      end

      # reader method for the raw data of the currently defined providers
      def data_provider_definitions
        ((@data_provider || {})[:provider_args] || [])
      end

      # returns wether a provider with the given identifier is available
      def has_provider?(identifier)
        (provides[identifier] || get_provider(identifier)) != nil
      end

      # adds all the providers defined in the given module to this class
      def add(providers_module)
        data = providers_module.instance_variable_get('@data_provider') || {}

        (data[:provider_args] || []).each do |definition|
          add_provider(*definition)
        end

        self.provides(data[:provides] || {})
      end

      # adds all the providers defined in the given module to this class,
      # but turns their identifiers into array and prefixes the array with the :scope option
      def add_scoped(providers_module, _options = {})
        data = providers_module.instance_variable_get('@data_provider') || {}

        (data[:provider_args] || []).each do |definition|
          definition[0] = [definition[0]].flatten
          definition[0] = [_options[:scope]].flatten.compact + definition[0] if _options[:scope]
          add_provider(*definition)
        end

        (data[:provides] || {}).each_pair do |key, value|
          provides(([_options[:scope]].flatten.compact + [key].flatten.compact) => value)
        end
      end

      private

      def add_provider(identifier, opts = {}, block = nil)
        @data_provider ||= {}
        @data_provider[:provider_args] ||= []
        @data_provider[:provider_args].unshift [identifier, opts, block]
      end
    end # module ClassMethods


    module InstanceMethods

      attr_reader :data
      attr_reader :options

      def initialize(opts = {})
        @options = opts.is_a?(Hash) ? opts : {}
        @data = options[:data].is_a?(Hash) ? options[:data] : {}
      end

      def logger
        @logger ||= options[:logger] || Logger.new(STDOUT)
      end

      def has_provider?(id)
        self.class.has_provider?(id)
      end

      def take(id)
        return self.class.provides[id] if self.class.provides.has_key?(id)
        provider = self.class.get_provider(id) #, :data => @data)
        raise ProviderMissingException.new(:message=>"Data provider tried to take data from missing provider.", :provider_id => id) if provider.nil?
        return instance_eval(&provider.block) 
      end

      def try_take(id)
        if !self.has_provider?(id)
          logger.debug "Try for missing provider: #{id.inspect}"
          return nil
        end

        return take(id)
      end

      def given(param_name)
        return data[param_name] if data.has_key?(param_name)
        logger.error "data provider expected missing data with identifier: #{param_name.inspect}"
        # TODO: raise?
        return nil
      end

      alias :get_data :given

      def give(_data = {})
        return self.class.new(options.merge(:data => data.merge(_data)))
      end

      alias :add_scope :give
      alias :add_data :give

      def give!(_data = {})
        @data = data.merge(_data)
        return self
      end

      alias :add_scope! :give!
      alias :add_data! :give!
    end # module InstanceMethods

  end # module Base

end # module DataProvider