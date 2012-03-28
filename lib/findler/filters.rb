class Findler::Filters
  # files first, then directories
  def self.files_first(paths)
    preserve_sort_by(paths) { |ea| ea.file? ? -1 : 1 }
  end

  # directories first, then files
  def self.directories_first(paths)
    preserve_sort_by(paths) { |ea| ea.directory? ? -1 : 1 }
  end

  # order by the mtime of each file. Oldest files first.
  def self.order_by_mtime_asc(paths)
    preserve_sort_by(paths)  { |ea| ea.mtime }
  end

  # reverse order by the mtime of each file. Newest files first.
  def self.order_by_mtime_desc(paths)
    preserve_sort_by(paths)  { |ea| -ea.mtime }
  end

  # order by the name of each file.
  def self.order_by_name(paths)
    preserve_sort_by(paths)  { |ea| ea.basename.to_s }
  end

  # reverse the order of the sort
  def self.reverse(paths)
    paths.reverse
  end

  def self.preserve_sort_by(array, &block)
    ea_to_index = Hash[array.zip((0..array.size-1).to_a)]
    array.sort_by do |ea|
      [yield(ea), ea_to_index[ea]]
    end
  end
end
