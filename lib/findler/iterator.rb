require 'set'
require 'forwardable'

class Findler
  class Iterator
    extend Forwardable
    def_delegators :@configuration,
      :ignore_case?, :include_hidden?,
      :filters, :filters_class, :fnmatch_flags,
      :patterns
    attr_reader :path

    def initialize(findler, path, parent_iterator = nil)
      @configuration = findler
      @path = Path.clean(path)
      @parent = parent_iterator
      @visited_dirs = Set.new
      @visited_files = Set.new
    end

    def children
      @children ||= begin
        children = @path.children.delete_if { |ea| skip?(ea) }
        filters.inject(children) { |c, f| filter(c, f) }
      end
    end

    def next_file
      return nil unless @path.exist?

      if @sub_iter
        nxt = @sub_iter.next_file
        return nxt unless nxt.nil?
        @visited_dirs.add(Path.base(@sub_iter.path))
        @sub_iter = nil
      end

      nxt = next_child
      return nil if nxt.nil?

      if nxt.directory?
        @sub_iter = Iterator.new(@configuration, nxt, self)
        self.next_file
      else
        @visited_files.add(Path.base(nxt))
        nxt
      end
    end

    private

    def next_child
      begin
        nxt = children.shift
      end while !nxt.nil? && !nxt.exist?
      nxt
    end

    def filter(children, filter_symbol)
      filtered_children = filters_class.send(filter_symbol, children)
      unless filtered_children.respond_to? :collect
        raise Error, "#{path.to_s}: filter_with, must return an Enumerable"
      end
      children_as_pathnames = Path.clean_array(filtered_children)
      illegal_children = children_as_pathnames - children
      unless illegal_children.empty?
        raise Error, "#{path.to_s}: filter_with returned unexpected paths: #{illegal_children.join(",")}"
      end
      children_as_pathnames
    end

    def skip?(pathname)
      k = Path.base(pathname)
      return true if !include_hidden? && Path.hidden?(pathname)
      return @visited_dirs.include?(k) if pathname.directory?
      return true if @visited_files.include?(k)
      @configuration.skip?(pathname)
    end
  end
end
