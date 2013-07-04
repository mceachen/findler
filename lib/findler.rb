require 'findler/error'
require 'findler/filters'
require 'findler/iterator'
require 'findler/path'

class Findler

  IGNORE_CASE = 1
  INCLUDE_HIDDEN = 2

  attr_reader :path

  def initialize(path)
    @path = Path.clean(path)
    @flags = 0
  end

  # These are File.fnmatch patterns.
  # If any pattern matches, it will be returned by Iterator#next.
  # (see File.fnmatch?)
  def patterns
    @patterns ||= []
  end

  def add_patterns(patterns)
    self.patterns += patterns
  end

  def add_pattern(pattern)
    self.patterns << pattern
  end

  def add_extension(extension)
    add_pattern "*#{normalize_extension(extension)}"
  end

  def add_extensions(extensions)
    extensions.each { |ea| add_extension(ea) }
  end

  # Should patterns be interpreted in a case-sensitive manner? The default is case sensitive,
  # but if your local filesystem is not case sensitive, this flag is a no-op.
  def case_sensitive!
    @flags &= ~IGNORE_CASE
  end

  def case_insensitive!
    @flags |= IGNORE_CASE
  end

  def ignore_case?
    (IGNORE_CASE & @flags) > 0
  end

  def include_hidden?
    (INCLUDE_HIDDEN & @flags) > 0
  end

  # Should we traverse hidden directories and files? (default is to skip files that start
  # with a '.')
  def include_hidden!
    @flags |= INCLUDE_HIDDEN
  end

  def exclude_hidden!
    @flags &= ~INCLUDE_HIDDEN
  end

  def fnmatch_flags
    @fnmatch_flags ||= begin
      f = 0
      f |= File::FNM_CASEFOLD if ignore_case?
      f |= File::FNM_DOTMATCH if include_hidden?
      f
    end
  end

  def filters_class
    (@filters_class ||= Filters)
  end

  def filters_class=(new_filters_class)
    raise Error unless new_filters_class.is_a? Class
    filters.each { |ea| new_filters_class.method(ea) } # verify the filters class has those methods defined
    @filters_class = new_filters_class
  end

  # Accepts symbols whose names are class methods on Finder::Filters.
  #
  # Filter methods receive an array of Pathname instances, and are in charge of ordering
  # and filtering the array. The returned array of pathnames will be used by the iterator.
  #
  # Those pathnames will:
  # a) have the same parent
  # b) will not have been enumerated by next() already
  # c) will satisfy the hidden flag and patterns preferences
  #
  # Note that the last filter added will be last to order the children, so it will be the
  # "primary" sort criterion.
  def add_filter(filter_symbol)
    filters_class.method(filter_symbol)
    filters << filter_symbol
  end

  def filters
    @filters ||= []
  end

  def add_filters(filter_symbols)
    filter_symbols.each { |ea| add_filter(ea) }
  end

  def iterator
    Iterator.new(self, path)
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

