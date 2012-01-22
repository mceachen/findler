class Findler

  VERSION = "0.0.2"

  IGNORE_CASE = 1
  INCLUDE_HIDDEN = 2

  autoload :Iterator, "findler/iterator"

  def initialize path
    @path = path
    @flags = 0
  end

  # These are File.fnmatch patterns. If any pattern matches, it will be returned by Iterator#next.
  # (see File.fnmatch?)
  def add_pattern *patterns
    patterns.each { |ea| (@patterns ||= []) << ea }
  end

  def append_extension *extensions
    extensions.each { |ea| add_pattern "*#{normalize_extension(ea)}" }
  end

  # Should patterns be interpreted in a case-insensitive manor? (default is case sensitive)
  def case_insensitive!
    @flags |= IGNORE_CASE
  end

  # Should we traverse hidden directories and files? (default is to skip files that start
  # with a '.')
  def include_hidden!
    @flags |= INCLUDE_HIDDEN
  end

  def iterator
    Iterator.new(:path => @path, :patterns => @patterns, :flags => @flags)
  end

  private

  def normalize_extension extension
    if extension.nil? || extension.empty? || extension.start_with?(".")
      extension
    else
      ".#{extension}"
    end
  end

end
