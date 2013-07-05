require 'minitest_helper'

class Findler::Filters
  def self.non_empty_files(children)
    (children.select { |ea| ea.directory? || ea.size > 0 })
  end

  def self.no_return(children)
  end

  def self.invalid_return(children)
    Pathname.new('/invalid/file')
  end

  def self.files_to_s(children)
    (children).collect { |ea| ea.to_s }
  end
end

describe Findler do

  def touch_secrets
    `mkdir .hide ; touch .outer-hide dir-0/.hide .hide/normal.txt .hide/.secret`
  end

  it "should detect hidden files properly" do
    %w(/a/b /.a/b).each do |ea|
      p = Pathname.new(ea)
      Findler::Path.hidden?(p).must_be_false
    end
    %w(/a/.b /a/.b).each do |ea|
      p = Pathname.new(ea)
      Findler::Path.hidden?(p).must_be_true
    end
  end

  it 'should skip hidden files by default' do
    with_tmp_dir do |dir|
      visible = (dir + rand_alphanumeric).tap { |ea| ea.touch }
      hidden = (dir + ".#{rand_alphanumeric}").tap { |ea| ea.touch }
      f = Findler.new(dir)
      f.send(:viable_path?, visible).must_equal true
      f.send(:viable_path?, hidden).must_equal false
      f.include_hidden!
      f.send(:viable_path?, visible).must_equal true
      f.send(:viable_path?, hidden).must_equal true
    end
  end

  it 'should find all non-hidden files by default' do
    with_tree(%W(.jpg .txt)) do |dir|
      touch_secrets
      f = Findler.new(dir)
      collect_files(f.iterator).must_equal_contents `find * -type f -not -name '.*'`.split
      f.exclude_hidden! # should be a no-op
      collect_files(f.iterator).must_equal_contents `find * -type f -not -name '.*'`.split
      f.include_hidden!
      collect_files(f.iterator).must_equal_contents `find . -type f | sed -e 's/^\\.\\///'`.split
    end
  end

  it 'should find only .jpg files when constrained' do
    with_tree(%W(.jpg .txt .JPG)) do |dir|
      f = Findler.new(dir)
      f.add_extension ".jpg"
      if fs_case_sensitive?
        f.case_sensitive!
        collect_files(f.iterator).must_equal_contents `find * -type f -name \\*.jpg`.split
      end
      f.case_insensitive!
      collect_files(f.iterator).must_equal_contents `find * -type f -iname \\*.jpg`.split
    end
  end

  it 'should find .jpg or .JPG files when constrained' do
    with_tree(%w(.jpg .txt .JPG)) do |dir|
      f = Findler.new(dir)
      f.add_extension ".jpg"
      f.case_insensitive!
      iter = f.iterator
      collect_files(iter).must_equal_contents `find * -type f -iname \\*.jpg`.split
    end
  end

  it 'should not return files removed after iteration started' do
    with_tree(%w(.txt)) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      iter.next_file.wont_be_nil
      sleep(1.1) # < make sure mtime change will be detected (which only has second resolution)
      (dir + "tmp-1.txt").unlink
      collect_files(iter).wont_include("tmp-1.txt")
    end
  end

  it 'should dump/load in the middle of iterating' do
    with_tree(%w(.jpg .txt .JPG)) do |dir|
      all_files = `find * -type f -iname \\*.jpg`.split
      all_files.size.times do |i|
        f = Findler.new(dir)
        f.add_extension ".jpg"
        f.case_insensitive!
        iter_a = f.iterator
        files_a = i.times.collect { relative_path(iter_a.path, iter_a.next_file) }
        iter_b = marshal_round_trip(iter_a)
        files_b = collect_files(iter_b)

        files_a.wont_include_any files_b
        files_b.wont_include_any files_a
        (files_a + files_b).must_equal_contents all_files

        # iter_b should be "exhausted" now.
        collect_files(iter_b).must_be_empty

        # and "exhaustion" should survive marshalling:
        iter_c = marshal_round_trip(iter_b)
        collect_files(iter_c).must_be_empty
      end
    end
  end

  it 'should create an iterator even for a non-existent directory' do
    tmpdir = nil
    Dir.mktmpdir do |dir|
      tmpdir = Pathname.new dir
    end
    tmpdir.exist?.must_equal false
    f = Findler.new(tmpdir)
    collect_files(f.iterator).must_be_empty
  end

  it 'should raise an error if the block given to next_file returns nil' do
    Dir.mktmpdir do |dir|
      f = Findler.new(dir)
      f.add_filter :no_return
      i = f.iterator
      lambda { i.next_file }.must_raise(Findler::Error)
    end
  end

  it 'raises an error if the block returns non-children' do
    with_tree(%W(.txt)) do |dir|
      f = Findler.new(dir)
      f.add_filter :invalid_return
      i = f.iterator
      lambda { i.next_file }.must_raise(Findler::Error)
    end
  end

  it 'raises error when filter methods return strings' do
    with_tree(%W(.txt)) do |dir|
      f = Findler.new(dir)
      f.add_filter :files_to_s
      i = f.iterator
      lambda { i.next_file }.must_raise(Findler::Error)
    end
  end

  it 'should support next_file blocks properly' do
    with_tree(%W(.a .b)) do |dir|
      Dir["**/*.a"].each { |ea| File.open(ea, 'w') { |f| f.write("hello") } }
      f = Findler.new(dir)
      f.add_filter :non_empty_files
      iter = f.iterator
      files = collect_files(iter)
      files.must_equal_contents `find * -type f -name \\*.a`.split
    end
  end

  it 'should support files_first ordering' do
    with_tree(%W(.a), {
      :depth => 2,
      :files_per_dir => 2,
      :subdirs_per_dir => 1,
    }) do |dir|
      f = Findler.new(dir)
      f.add_filters([:order_by_name, :files_first])
      expected = %W(tmp-0.a tmp-1.a dir-0/tmp-0.a dir-0/tmp-1.a)
      collect_files(f.iterator).must_equal expected
      f.add_filter :reverse
      collect_files(f.iterator).must_equal expected.reverse
    end
  end

  it 'should support directory_first ordering' do
    with_tree(%W(.a), {
      :depth => 2,
      :files_per_dir => 2,
      :subdirs_per_dir => 1,
    }) do |dir|
      f = Findler.new(dir)
      f.add_filters([:order_by_name, :directories_first])
      expected = %W(dir-0/tmp-0.a dir-0/tmp-1.a tmp-0.a tmp-1.a)
      collect_files(f.iterator).must_equal expected
      f.add_filter :reverse
      collect_files(f.iterator).must_equal expected.reverse
    end
  end
end
