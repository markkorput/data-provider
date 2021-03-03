module DataProvider

  class ProviderMissingException < Exception
    attr_reader :params

    def initialize(_params = {})
      @params = _params || {}
      super(params[:message] || "Tried to take data from missing provider: #{provider_id.inspect}")
    end

    def provider_id
      params[:provider_id]
    end
  end


  class Container
    attr_reader :options

    def initialize _opts = {}
      @options = _opts.is_a?(Hash) ? _opts : {}
    end

    def logger
      @logger ||= options[:logger] || Logger.new(STDOUT).tap do |lger|
        lger.level = Logger::WARN
      end
    end

    def default_priority
      options[:default_priority].to_i
    end

    def provider identifier, opts = {}, &block
      add_provider(identifier, opts, block_given? ? block : nil)
    end

    def has_provider?(identifier)
      (provides.keys.find{|k| k == identifier} || get_provider(identifier)) != nil
    end

    def providers_with_scope(args)
      scope = args.is_a?(Array) ? args : [args]
      provider_identifiers.select{|id| id.is_a?(Array) && id.length > scope.length && id[0..(scope.length-1)] == scope}
    end

    def has_providers_with_scope?(args)
       providers_with_scope(args).any?
    end

    def has_filled_providers_with_scope?(current_stack, opts)
      if opts[:include_current] == true
        current_content_data = try_take(current_stack, opts)
        return false if current_content_data.respond_to?(:empty?) && current_content_data.empty?
        return true if !current_content_data.nil? && !(current_content_data.is_a?(XsdPopulator::Informer) && current_content_data.skip?)
      end

      return false unless has_providers_with_scope?(current_stack)

      providers_with_scope(current_stack).sort_by{ |prov_id| prov_id.size }.each do |provider_id|
        return false if provider_id.last.is_a?(Symbol) # Ignore private symbolized providers for this check.

        content_data = try_take(provider_id, opts)
        return true if !content_data.nil? && !(content_data.is_a?(XsdPopulator::Informer) && content_data.skip?) && (content_data.respond_to?(:any?) ? content_data.any? : true)
      end

      false
    end

    def force_build_node?(*args)
      scope = args.is_a?(Array) ? args.flatten : [args]
      provider = get_provider(scope)
      provider && provider.force_build_node?
    end

    def provider_identifiers
      (provides.keys + providers.map(&:first)).compact.uniq
    end

    # provides, when called with a hash param, will define 'simple providers' (providers
    # with a simple, static value). When called without a param (or nil) it returns
    # the current cumulative 'simple providers' hash
    def provides _provides = nil
      return @provides || {} if _provides.nil?
      add_provides _provides
      return self
    end

    def providers
      @providers || []
    end

    def provider_missing &block
      raise "DataProvider::Base#provider_missing expects a block as an argument" if !block_given?
      @fallback_provider = block
    end

    def fallback_provider
      block = @fallback_provider
      block.nil? ? nil : Provider.new(nil, nil, block)
    end

    def fallback_provider?
      !fallback_provider.nil?
    end

    def take(id, opts = {})
      logger.debug "DataProvider::Container#take with id: #{id.inspect}"

      # first try the simple providers
      if provides.has_key?(id) && opts[:skip].nil?
        provider = provides[id]
        return provider.is_a?(Proc) ? provider.call : provider
      end

      # try to get a provider object
      provider = get_provider(id, :skip => opts[:skip])
      if provider
        @stack = (@stack || []) + [provider]
        @skip_stack = (@skip_stack || []) + [opts[:skip].to_i]
        result = (opts[:scope] || self).instance_eval(&provider.block) 
        @skip_stack.pop
        @stack.pop
        # execute provider object's block within the scope of self
        return result
      end

      # try to get a scoped provider object
      if scope.length > 0
        scoped_id = [scope, id].flatten
        provider = get_provider(scoped_id, :skip => opts[:skip])
        if provider
          @stack = (@stack || []) + [provider]
          @skip_stack = (@skip_stack || []) + [opts[:skip].to_i]
          result = (opts[:scope] || self).instance_eval(&provider.block) 
          @skip_stack.pop
          @stack.pop
          # execute provider object's block within the scope of self
          return result
        end
      end

      # couldn't find requested provider, let's see if there's a fallback
      if provider = fallback_provider
        # temporarily set the @missing_provider instance variable, so the
        # fallback provider can use it through the missing_provider private method
        @missing_provider = id
        @stack = (@stack || []) + [provider]
        @skip_stack = (@skip_stack || []) + [opts[:skip].to_i]
        result = (opts[:scope] || self).instance_eval(&provider.block) # provider.block.call # with the block.call method the provider can't access private methods like missing_provider
        @skip_stack.pop
        @stack.pop # = nil
        @missing_provider = nil
        return result
      end

      # no fallback either? Time for an error
      raise ProviderMissingException.new(:provider_id => id) 
    end

    def try_take(id, opts = {})
      return take(id, opts) if self.has_provider?(id) || self.fallback_provider?
      logger.debug "Try for missing provider: #{id.inspect}"
      return nil
    end

    # take_super is only meant to be called form inside a provider
    # returns the result of next provider with the same ID
    def take_super(opts = {})
      take(provider_id, opts.merge(:skip => current_skip + 1))
    end

    #
    # "adding existing containers"-related methods
    #

    # adds all the providers defined in the given module to this class
    def add!(container)
      ### add container's providers ###
      # internally providers are added in reverse order (last one first)
      # so at runtime you it's easy and fast to grab the latest provider
      # so when adding now, we have to reverse the providers to get them in the original order
      container.providers.reverse.each do |definition|
        add_provider(*definition)
      end

      ### add container's provides (simple providers) ###
      self.provides(container.provides)

      ### fallback provider ###
      @fallback_provider = container.fallback_provider.block if container.fallback_provider

      ### add container's data ###
      give!(container.data)
    end

    def add(container)
      # make a copy and add the container to that 
      give({}).add!(container)
    end

    # adds all the providers defined in the given module to this class,
    # but turns their identifiers into array and prefixes the array with the :scope option
    def add_scoped! container, _options = {}
      ### add container's providers ###
      container.providers.reverse.each do |definition|
        identifier = [definition[0]].flatten
        identifier = [_options[:scope]].flatten.compact + identifier if _options[:scope]
        add_provider(*([identifier]+definition[1..-1]))
      end

      ### add container's provides (simple providers) ###
      container.provides.each_pair do |key, value|
        provides(([_options[:scope]].flatten.compact + [key].flatten.compact) => value)
      end

      ### fallback provider ###
      @fallback_provider = container.fallback_provider.block if container.fallback_provider

      ### add container's data ###
      give!(container.data)
    end

    # adds all the providers defined in the given module to this class,
    # but turns their identifiers into array and prefixes the array with the :scope option
    def add_scoped container, _options = {}
      copy.add_scoped!(container, _options)
    end

    #
    # Data-related methods
    #

    def copy
      c = self.class.new
      c.add!(self)
    end

    def data
      @data || {}
    end

    def give(_data = {})
      copy.give!(_data)
    end

    alias :add_scope :give
    alias :add_data :give

    def give!(_data = {})
      @data ||= {}
      @data.merge!(_data)
      return self
    end

    alias :add_scope! :give!
    alias :add_data! :give!

    def given(param_name)
      return data[param_name] if got?(param_name)
      logger.debug "Data provider expected missing data with identifier: #{param_name.inspect}"
      # TODO: raise?
      return nil
    end

    alias :get_data :given


    def got?(param_name)
      data.has_key?(param_name)
    end

    alias :has_data? :got?

    def missing_provider
      @missing_provider
    end

    def scoped_take(id)
      take(scope + [id].flatten)
    end

    def provider_stack
      (@stack || []).clone
    end

    def current_provider
      provider_stack.last
    end

    def provider_id
      current_provider ? current_provider.id : nil
    end

    def scopes
      provider_stack.map{|provider| provider.id.is_a?(Array) ? provider.id[0..-2] : []}
    end

    def scope
      scopes.last || []
    end

    def current_skip
      (@skip_stack || []).last.to_i
    end

  private

    def add_provider(identifier, opts = {}, block = nil)
      @providers ||= []
      @providers.unshift [identifier, opts, block]
    end

    def add_provides _provides = {}
      if _provides.is_a?(Hash) != true
        logger.error 'DataProvider::Container#add_provides received non-hash param'
        return @provides
      end

      @provides ||= {}
      @provides.merge! _provides
    end

    # returns the requested provider as a Provider object
    def get_provider(id, opts = {})
      # get all matching providers
      matching_provider_args = providers.find_all{|args| args.first == id}
      # sort providers on priority, form high to low
      matching_provider_args.sort! do |args_a, args_b|
        # we want to sort from high priority to low, but providers with the same priority level
        # should stay in the same order because among those, the last one added has the highest priority
        # (last added means first in the array, since they are pushed into the beginning of the array)
        (Provider.new(*args_b).priority || self.default_priority) <=> (Provider.new(*args_a).priority || self.default_priority)
      end
      # if no skip option is given, opts[:skip].to_i will result in zero, so it'll grab thefirst from the array
      # if the array is empty, args will always turn out nil
      args = matching_provider_args[opts[:skip].to_i]

      return args.nil? ? nil : Provider.new(*args)
    end
  end # class Container
end # module DataProvider