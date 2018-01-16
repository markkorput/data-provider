module DataProvider
  class Provider
    attr_reader :options
    attr_reader :identifier
    attr_reader :block

    def initialize(identifier, opts = {}, block = nil)
      @identifier = identifier
      @options = opts.is_a?(Hash) ? opts : {}
      @block = block || Proc.new
    end

    alias_method :id, :identifier

    def requirements
      [options[:requires]].flatten.compact
    end

    def priority
      options[:priority]
    end

    def force_build_node?
      options[:force_build] == true
    end
  end # module Provider
end # module DataProvider