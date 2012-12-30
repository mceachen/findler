require 'minitest_helper'

describe Findler::Filters do
  it "should preserve sort order with no result" do
    a = %w(h a p p y)
    b = Findler::Filters.preserve_sort_by(a) { 0 }
    b.must_equal a
  end

  it "should preserve sort order" do
    a = [3.5, 3.1, 1.1, 2.0, 1.5, 1.3]
    b = Findler::Filters.preserve_sort_by(a) { |ea| ea.to_i }
    b.must_equal [1.1, 1.5, 1.3, 2.0, 3.5, 3.1]
  end
end
