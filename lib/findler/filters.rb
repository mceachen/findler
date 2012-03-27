class Findler::Filters
  # files first, then directories, then sort by name (to be deterministic)
  def self.breadth_first_search(paths)
    preserve_sort_by(paths) { |ea| ea.file? ? -1 : 1 }
  end

  # directories first, then files, then sort by name (to be deterministic)
  def self.depth_first_search(paths)
    preserve_sort_by(paths) { |ea| ea.file? ? 1 : -1 }
  end

  # order by the mtime of each file. Oldest files first.
  def self.mtime_asc(paths)
    preserve_sort_by(paths)  { |ea| ea.mtime }
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
