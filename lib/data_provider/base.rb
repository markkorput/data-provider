require 'logger'

module DataProvider

  module Base

    def self.included(base)
      base.class_eval do
        include InstanceMethods
        include ProxyMethods
        extend ClassMethods
        extend ProxyMethods
      end
    end

    # both instance- class-level
    module ProxyMethods
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

      def providers_with_scope(*args)
        dpc.providers_with_scope(*args)
      end

      def has_providers_with_scope?(*args)
        dpc.has_providers_with_scope?(*args)
      end

      def has_filled_providers_with_scope?(*args)
        dpc.has_filled_providers_with_scope?(*args, scope: self)
      end

      def fallback_provider?
        dpc.fallback_provider?
      end

      def force_build_node?(*args)
        dpc.force_build_node?(*args)
      end

      def provider_missing *args, &block
        dpc.provider_missing *args, &block
      end

      def take(id, opts = {})
        dpc.take(id, opts.merge(:scope => self))
      end

      def try_take(id, opts = {})
        dpc.try_take(id, opts.merge(:scope => self))
      end

      def got?(*args)
        dpc.got?(*args)
      end

      alias :has_data? :got?

      def given *args
        dpc.given *args
      end

      alias :get_data :given

      def give! *args
        dpc.give! *args
        return self
      end

      alias :add_scope! :give!
      alias :add_data! :give!

      private

      def missing_provider *args
        dpc.missing_provider *args
      end

      def scoped_take *args
        dpc.scoped_take *args
      end

      def scope *args
        dpc.scope *args
      end

      def scopes *args
        dpc.scopes *args
      end

      def provider_stack *args
        dpc.provider_stack *args
      end

      def provider_id *args
        dpc.provider_id *args
      end

      def take_super
        dpc.take_super(:scope => self)
      end
    end

    module ClassMethods
      def data_provider_container
        @data_provider_container ||= DataProvider::Container.new
      end

      alias :dpc :data_provider_container

      # can't copy self on a class-level
      def give *args
        dpc.give! *args
        return self
      end

      # alias :give :give!
      alias :add_scope :give
      alias :add_data :give

      def add! _module
        if _module.is_a?(DataProvider::Container)
          dpc.add!(_module)
        else
          dpc.add!(_module.dpc)
        end

        include _module
        return self
      end

      def add_scoped! _module, options = {}
        if _module.is_a?(DataProvider::Container)
          dpc.add_scoped!(_module, options) 
        else
          dpc.add_scoped! _module.dpc, options
        end

        include _module
        return self
      end

      # classes/modules can't be cloned, so add behaves just like add!
      alias :add :add!
      alias :add_scoped :add_scoped!
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

      def add _module
        if _module.is_a?(DataProvider::Container)
          _dpc = _module
        else
          _dpc = _module.dpc
          self.class.class_eval do
            include _module # todo: make optional?
          end
        end

        self.class.new(options.merge({
          :data => nil,
          :dpc => dpc.add(_dpc)
        }))
      end

      def add_scoped _module, options = {}
        if _module.is_a?(DataProvider::Container)
          _dpc = _module
        else
          _dpc = _module.dpc
          self.class.class_eval do
            include _module # todo: make optional?
          end
        end

        self.class.new(options.merge({
          :data => nil,
          :dpc => dpc.add_scoped(_dpc, :scope => options[:scope])
        }))
      end

      def give *args
        self.class.new(options.merge(:data => nil, :dpc => self.dpc.give(*args)))
      end

      alias :add_scope :give
      alias :add_data :give

      def add! _module
        if _module.is_a?(DataProvider::Container)
          dpc.add!(_module)
        else
          dpc.add!(_module.dpc)
          self.class.class_eval do
            include _module
          end
        end
        
        return self
      end

      def add_scoped! _module, options = {}
        if _module.is_a?(DataProvider::Container)
          dpc.add_scoped!(_module, options) 
        else
          dpc.add_scoped! _module.dpc, options
          self.class.class_eval do
            include _module
          end
        end
        
        return self
      end
    end # module InstanceMethods
  end # module Base
end # module DataProvider