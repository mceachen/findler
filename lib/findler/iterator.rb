require 'bloomer'

class Findler
  class Iterator

    def initialize(attrs, parent = nil)
      @path = attrs[:path]
      @path = Pathname.new(@path) unless @path.is_a? Pathname
      @visited = attrs[:visited] || Bloomer.new(@path.children.size, 0.00001) # <= highly unlikely
      @patterns = attrs[:patterns]
      @flags = attrs[:flags]
      @parent = parent
      @sub_iter = self.class.new(attrs[:sub_iter], self) if attrs[:sub_iter]
    end

    def to_hash
      {:path => @path, :visited => @visited, :patterns => @patterns, :flags => @flags, :sub_iter => @sub_iter && @sub_iter.to_hash}
    end

    def _dump(depth)
      Marshal.dump(to_hash)
    end

    def self._load(data)
      new(Marshal.load(data))
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
        @visited.add @sub_iter.path.basename.to_s
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
        @visited.add nxt.basename.to_s
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
  end
end