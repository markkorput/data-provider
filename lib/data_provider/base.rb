require 'logger'

module DataProvider

  module Base

    def self.included(base)
      base.class_eval do
        include InstanceMethods
        extend ClassMethods
      end
    end

    module ClassMethods
      def data_provider_container
        @data_provider_container ||= DataProvider::Container.new
      end

      alias :dpc :data_provider_container

      def provides *args
        return dpc.provides if args.length == 0
        dpc.provides *args
        return self
      end

      def provider_identifiers *args
        dpc.provider_identifiers *args
      end

      def provider *args, &block
        dpc.provider *args, &block
      end

      def has_provider? *args
        dpc.has_provider? *args
      end

      def has_providers_with_scope?(*args)
        dpc.has_providers_with_scope?(*args)
      end

      def fallback_provider?
        dpc.fallback_provider?
      end

      def add _module
        return dpc.add!(_module) if _module.is_a?(DataProvider::Container)
        include _module
        dpc.add!(_module.dpc)
      end

      def add_scoped _module, options = {}
        return dpc.add_scoped!(_module, options) if _module.is_a?(DataProvider::Container)
        include _module
        dpc.add_scoped! _module.dpc, options
      end

      def provider_missing *args, &block
        dpc.provider_missing *args, &block
      end
    end # module ClassMethods


    module InstanceMethods

      attr_reader :options

      def initialize(opts = {})
        @options = opts.is_a?(Hash) ? opts : {}
        dpc.give!(options[:data]) if options[:data].is_a?(Hash)
      end

      def logger
        @logger ||= options[:logger] || Logger.new(STDOUT).tap do |lger|
          lger.level = Logger::WARN
        end
      end

      def data_provider_container
        @data_provider_container ||= options[:dpc] || DataProvider::Container.new.tap do |c|
          # automatically adopt all class-level providers/provides/data
          c.add! self.class.dpc
        end
      end

      alias :dpc :data_provider_container

      def has_provider?(*args)
        dpc.has_provider?(*args)
      end

      def has_providers_with_scope?(*args)
        dpc.has_providers_with_scope?(*args)
      end

      def fallback_provider?
        dpc.fallback_provider?
      end

      def take(*args)
        dpc.take(*args)
      end

      def try_take(*args)
        dpc.try_take(*args)
      end

      def got?(*args)
        dpc.got?(*args)
      end

      alias :has_data? :got?

      def given *args
        dpc.given *args
      end

      alias :get_data :given

      def give *args
        self.class.new(options.merge(:data => nil, :dpc => self.dpc.give(*args)))
      end

      alias :add_scope :give
      alias :add_data :give

      def give! *args
        dpc.give! *args
      end

      alias :add_scope! :give!
      alias :add_data! :give!
    end # module InstanceMethods

  end # module Base

end # module DataProvider