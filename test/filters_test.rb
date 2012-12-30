require 'minitest_helper'

describe Findler::Filters do
  it "preserves sort order with no result" do
    a = %w(h a p p y)
    b = Findler::Filters.preserve_sort_by(a) { 0 }
    b.must_equal a
  end

  it "preserves sort order" do
    a = [3.5, 3.1, 1.1, 2.0, 1.5, 1.3]
    b = Findler::Filters.preserve_sort_by(a) { |ea| ea.to_i }
    b.must_equal [1.1, 1.5, 1.3, 2.0, 3.5, 3.1]
  end

  it "sorts by mtime" do
    with_tmp_dir do
      srand(8675309) # <- stable rand()
      names = 10.times.collect { rand_alphanumeric + ".txt" }
      names.each_with_index do |ea, index|
        FileUtils.touch ea, :mtime => (Time.now.to_i + index)
      end
      paths = names.collect { |ea| Pathname.new(ea) }
      glob = Pathname.glob("*.txt")
      glob.wont_equal(paths) # because the order was random.
      Findler::Filters.order_by_mtime_asc(glob).must_equal(paths)
      Findler::Filters.order_by_mtime_desc(glob).must_equal(paths.reverse)
    end
  end
end
