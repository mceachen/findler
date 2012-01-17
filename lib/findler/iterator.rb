# Use fnmatch?
class Findler
  class Iterator
    YAML_VERSION = 0

    def self.from_yaml(yaml_string, parent = nil)
      return nil if yaml_string.nil?
      h = YAML.load(yaml_string)
      v = h.delete(:version)
      if v && YAML_VERSION != v
        raise StandardError "Can't deserialize version #{v}"
      end
      new(h, parent)
    end

    def initialize(attrs, parent = nil)
      @path = attrs[:path]
      @path = Pathname.new(@path) unless @path.is_a? Pathname
      @visited = attrs[:visited] || []
      @patterns = attrs[:patterns]
      @flags = attrs[:flags]
      @parent = parent
      @sub_iter = self.class.from_yaml(attrs[:sub_iter], self)
    end

    def flags
      @parent ? @parent.flags : @flags
    end

    def case_insensitive?
      (Findler::IGNORE_CASE | flags) != 0
    end

    def skip_hidden?
      (Findler::INCLUDE_HIDDEN | flags) == 0
    end

    def patterns
      @parent ? @parent.patterns : @patterns
    end

    def fnmatch_flags
      (@parent && @parent.fnmatch_flags) || begin
        f = 0
        f |= File::FNM_CASEFOLD if case_insensitive?
        f |= File::FNM_DOTMATCH if !skip_hidden?
        f
      end
    end

    def path
      @path
    end

    def next
      if @sub_iter
        nxt = @sub_iter.next
        return nxt unless nxt.nil?
        @visited << @sub_iter.path.basename.to_s
        @sub_iter = nil
      end

      # If someone touches the directory while we iterate, redo the @children.
      @children = nil if @path.mtime != @mtime
      @children ||= begin
        @mtime = @path.mtime
        @path.
          children.
          delete_if do |ea|
          skip?(ea)
        end
      end

      nxt = @children.shift
      return nil if nxt.nil?

      if nxt.directory?
        @sub_iter = Iterator.new({:path => nxt}, self)
        self.next
      else
        @visited << nxt.basename.to_s
        nxt
      end
    end

    private

    def hidden?(pathname)
      pathname.basename.to_s.start_with?(".")
    end

    def skip? pathname
      return true if @visited.include?(pathname.basename.to_s)
      return true if hidden?(pathname) && skip_hidden?
      return false if pathname.directory?
      return false if patterns.nil?
      path = pathname.cleanpath
      return !patterns.any? { |p| File.fnmatch(p, path, fnmatch_flags) }
    end

    def to_yaml
      attrs = {}
      ATTRS.each { |ea| attrs[ea] = self.instance_variable_get(ea) }
      attrs.to_yaml
    end
  end
end