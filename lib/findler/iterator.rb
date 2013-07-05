require 'set'
require 'forwardable'

class Findler
  class Iterator
    extend Forwardable
    def_delegators :@configuration, :filter_paths
    attr_reader :path

    def initialize(findler, path, parent_iterator = nil)
      @configuration = findler
      @path = Path.clean(path).freeze
      @parent = parent_iterator
      @visited = []
    end

    def next_file
      return nil unless @path.exist?

      if @sub_iter
        nxt = @sub_iter.next_file
        return nxt unless nxt.nil?
        mark_visited(@sub_iter.path)
        @sub_iter = nil
      end

      nxt = next_visitable_child
      return nil if nxt.nil?

      if nxt.directory?
        @sub_iter = Iterator.new(@configuration, nxt, self)
        self.next_file
      else
        mark_visited(nxt)
        nxt
      end
    end

    private

    def children
      # If someone touches the directory while we iterate, redo the @children.
      if @children.nil? || @mtime != @path.mtime || @ctime != @path.ctime
        @mtime = @path.mtime
        @ctime = @path.ctime
        @children = filter_paths(@path.children)
      end
      @children
    end

    def next_visitable_child
      children.detect { |ea| !@visited.include?(Path.base(ea)) }
    end

    def mark_visited(path)
      @visited << Path.base(path)
    end
  end
end
