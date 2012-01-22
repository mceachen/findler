require 'bloomer'

class Findler
  class Iterator

    attr_reader :path, :parent, :patterns, :flags, :visited_dirs, :visited_files

    def initialize(attrs, parent = nil)
      @path = attrs[:path]
      @path = Pathname.new(@path) unless @path.is_a? Pathname
      @parent = parent

      set_ivar(:visited_dirs, attrs) { Bloomer::Scalable.new(256, 1.0/1_000_000) }
      set_ivar(:visited_files, attrs) { Bloomer::Scalable.new(256, 1.0/1_000_000) }
      set_ivar(:patterns, attrs) { nil }
      set_ivar(:flags, attrs) { 0 }

      @sub_iter = self.class.new(attrs[:sub_iter], self) if attrs[:sub_iter]
    end

    # Visit this directory and all sub directories, and check for unseen files. Only call on the root iterator.
    def rescan!
      raise "Only invoke on root" unless @parent.nil?
      @visited_dirs = Bloomer::Scalable.new(256, 1.0/1_000_000)
      @children = nil
      @sub_iter = nil
    end

    #def to_hash
    #  {:path => @path, :visited_dirs:patterns => @patterns, :flags => @flags, :sub_iter => @sub_iter && @sub_iter.to_hash}
    #end
    #
    #def _dump(depth)
    #  Marshal.dump(to_hash)
    #end
    #
    #def self._load(data)
    #  new(Marshal.load(data))
    #end

    def case_insensitive?
      (Findler::IGNORE_CASE | flags) != 0
    end

    def skip_hidden?
      (Findler::INCLUDE_HIDDEN | flags) == 0
    end

    def fnmatch_flags
      @_fnflags ||= (@parent && @parent.fnmatch_flags) || begin
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
      return nil unless @path.exist?
      
      if @sub_iter
        nxt = @sub_iter.next
        return nxt unless nxt.nil?
        @visited_dirs.add @sub_iter.path.to_s
        @sub_iter = nil
      end

      # If someone touches the directory while we iterate, redo the @children.
      @children = nil if @path.ctime != @ctime || @path.mtime != @mtime
      @children ||= begin
        @mtime = @path.mtime
        @ctime = @path.ctime
        @path.children.delete_if { |ea| skip?(ea) }
      end

      nxt = @children.shift
      return nil if nxt.nil?

      if nxt.directory?
        @sub_iter = Iterator.new({:path => nxt}, self)
        self.next
      else
        @visited_files.add nxt.to_s
        nxt
      end
    end

    private

    def set_ivar(field, attrs, &block)
      sym = "@#{field}".to_sym
      v = attrs[field]
      v ||= begin
        (p = instance_variable_get(:@parent)) && p.instance_variable_get(sym)
      end
      v ||= yield
      instance_variable_set(sym, v)
    end

    def hidden?(pathname)
      pathname.basename.to_s.start_with?(".")
    end

    def skip? pathname
      s = pathname.to_s
      return true if hidden?(pathname) && skip_hidden?
      return @visited_dirs.include?(s) if pathname.directory?
      return true if @visited_files.include?(s)
      unless patterns.nil?
        return true if patterns.none? { |p| pathname.fnmatch(p, fnmatch_flags) }
      end
      return false
    end
  end
end