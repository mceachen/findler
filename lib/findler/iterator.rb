require 'pathname'

class Findler

  class Iterator

    attr_reader :path, :parent, :patterns, :flags, :filters_class, :filters, :visited_dirs, :visited_files

    def initialize(attrs, parent = nil)
      @path = attrs[:path]
      @path = Pathname.new(@path) unless @path.is_a? Pathname
      @path = @path.expand_path unless @path.absolute?
      @parent = parent

      @visited_dirs = Set.new
      @visited_files = Set.new
      set_inheritable_ivar(:patterns, attrs) { nil }
      set_inheritable_ivar(:flags, attrs) { 0 }
      set_inheritable_ivar(:filters, attrs) { [] }
      set_inheritable_ivar(:filters_class, attrs) { Filters }
      set_inheritable_ivar(:sort_with, attrs) { nil }

      @sub_iter = self.class.new(attrs[:sub_iter], self) if attrs[:sub_iter]
    end

    def ignore_case?
      (Findler::IGNORE_CASE & flags) > 0
    end

    def include_hidden?
      (Findler::INCLUDE_HIDDEN & flags) > 0
    end

    def fnmatch_flags
      @fnmatch_flags ||= (@parent && @parent.fnmatch_flags) || begin
        f = 0
        f |= File::FNM_CASEFOLD if ignore_case?
        f |= File::FNM_DOTMATCH if include_hidden?
        f
      end
    end

    def path
      @path
    end

    def next_file
      return nil unless @path.exist?

      if @sub_iter
        nxt = @sub_iter.next_file
        return nxt unless nxt.nil?
        @visited_dirs.add @sub_iter.path.to_s
        @sub_iter = nil
      end

      # If someone touches the directory while we iterate, redo the @children.
      @children = nil if @path.ctime != @ctime || @path.mtime != @mtime

      if @children.nil?
        @mtime = @path.mtime
        @ctime = @path.ctime
        children = @path.children.delete_if { |ea| skip?(ea) }
        filtered_children = @filters.inject(children){ |c, f| filter(c, f) }
        @children = filtered_children
      end

      nxt = @children.shift
      return nil if nxt.nil?

      if nxt.directory?
        @sub_iter = Iterator.new({:path => nxt}, self)
        self.next_file
      else
        @visited_files.add(pathname_as_key(nxt))
        nxt
      end
    end

    private

    def pathname_as_key(pathname)
      pathname.basename.to_s
    end

    def filter(children, filter_symbol)
      filtered_children = filters_class.send(filter_symbol, children)
      unless filtered_children.respond_to? :collect
        raise Error, "#{path.to_s}: filter_with, must return an Enumerable"
      end
      children_as_pathnames = filtered_children.collect { |ea| ea.is_a?(Pathname) ? ea : Pathname.new(ea) }
      illegal_children = children_as_pathnames - children
      unless illegal_children.empty?
        raise Error, "#{path.to_s}: filter_with returned unexpected paths: #{illegal_children.join(",")}"
      end
      children_as_pathnames
    end

    # Sets the instance variable to the value in attrs[field].
    # If attrs is missing a value, pull the value from the parent.
    # If the parent doesn't have a value, use the block to generate a default.
    def set_inheritable_ivar(field, attrs, &block)
      v = attrs[field]
      sym = "@#{field}".to_sym
      v ||= parent.instance_variable_get(sym)
      v ||= yield
      instance_variable_set(sym, v)
    end

    def hidden?(pathname)
      pathname.basename.to_s.start_with?(".")
    end

    def skip?(pathname)
      s = pathname.to_s
      k = pathname_as_key(pathname)
      return true if !include_hidden? && hidden?(pathname)
      return visited_dirs.include?(k) if pathname.directory?
      return true if visited_files.include?(k)
      unless patterns.nil?
        return true if patterns.none? { |p| pathname.fnmatch(p, fnmatch_flags) }
      end
      false
    end
  end
end
