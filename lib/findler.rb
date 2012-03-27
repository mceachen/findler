class Findler

  autoload :Iterator, "findler/iterator"
  autoload :Error, "findler/error"
  require "findler/filters"

  IGNORE_CASE = 1
  INCLUDE_HIDDEN = 2

  def initialize(path)
    @path = path
    @flags = IGNORE_CASE # given that both mac and windows ignore case...
  end

  # These are File.fnmatch patterns.
  # If any pattern matches, it will be returned by Iterator#next.
  # (see File.fnmatch?)
  def patterns
    @patterns ||= []
  end

  def add_patterns(*patterns)
    self.patterns += patterns
  end

  def add_pattern(pattern)
    self.patterns << pattern
  end

  def add_extension(extension)
    add_pattern "*#{normalize_extension(extension)}"
  end

  def add_extensions(*extensions)
    extensions.each { |ea| add_extension(ea) }
  end

  # Should patterns be interpreted in a case-sensitive manner? (default is case insensitive)
  def case_sensitive!
    @flags &= ~IGNORE_CASE
  end

  def case_insensitive!
    @flags |= IGNORE_CASE
  end

  # Should we traverse hidden directories and files? (default is to skip files that start
  # with a '.')
  def include_hidden!
    @flags |= INCLUDE_HIDDEN
  end

  def exclude_hidden!
    @flags &= ~INCLUDE_HIDDEN
  end

  def filter_class
    (@filter_class ||= Filters)
  end

  def filter_class=(new_filter_class)
    raise Error unless new_filter_class.is_a? Class
    filters.each{|ea|new_filter_class.method(ea)} # verify the filters class has those methods defined
    @filter_class = new_filter_class
  end

  # Accepts symbols whose names are class methods on Finder::Filters. Order is perserved.
  #
  # Filter methods receive an array of Pathname instances, and are in charge of ordering
  # and filtering the array. The returned array of pathnames will be used by the iterator.
  #
  # Those pathnames will:
  # a) have the same parent
  # b) will not have been enumerated by next() already
  # c) will satisfy the hidden flag and patterns preferences
  def add_filter(filter_symbol)
    filter_class.method(filter_symbol)
    filters << filter_symbol
  end

  def filters
    (@filters ||= [])
  end

  def add_filters(*filter_symbols)
    filter_symbols.each { |ea| add_filter(ea) }
  end

  def iterator
    Iterator.new(:path => @path,
                 :patterns => @patterns,
                 :flags => @flags,
                 :filters => @filters)
  end

  private

  def normalize_extension(extension)
    if extension.nil? || extension.empty? || extension.start_with?(".")
      extension
    else
      ".#{extension}"
    end
  end
end

