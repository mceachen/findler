require 'test_helper'

class Findler::Filters
  def self.non_empty_files(children)
    (children.select { |ea| ea.directory? || ea.size > 0 })
  end

  def self.no_return(children)
  end

  def self.invalid_return(children)
    "/invalid/file"
  end

  def self.files_to_s(children)
    (children).collect { |ea| ea.to_s }
  end
end

describe Findler do

  before :each do
    @opts = {
        :depth => 3,
        :files_per_dir => 3,
        :subdirs_per_dir => 3,
        :prefix => "tmp",
        :suffix => "",
        :dir_prefix => "dir",
        :dir_suffix => ""
    }
  end

  def touch_secrets
    `mkdir .hide ; touch .outer-hide dir-0/.hide .hide/normal.txt .hide/.secret`
  end

  it "should detect hidden files properly" do
    i = Findler::Iterator.new(:path => "/tmp")
    i.send(:hidden?, Pathname.new("/a/b")).must_equal false
    i.send(:hidden?, Pathname.new("/a/.b")).must_equal true
    i.send(:hidden?, Pathname.new("/.a/.b")).must_equal true
    i.send(:hidden?, Pathname.new("/.a/b")).must_equal false
  end

  it "should skip hidden files by default" do
    i = Findler.new("/tmp").iterator
    i.send(:skip?, Pathname.new("/tmp/not-hidden")).must_equal false
    i.send(:skip?, Pathname.new("/tmp/.hidden")).must_equal true
  end

  it "should not skip hidden files when set" do
    f = Findler.new("/tmp")
    f.include_hidden!
    i = f.iterator
    i.send(:skip?, Pathname.new("/tmp/not-hidden")).must_equal false
    i.send(:skip?, Pathname.new("/tmp/.hidden")).must_equal false
  end

  it "should find all non-hidden files by default" do
    with_tree(%W(.jpg .txt)) do |dir|
      touch_secrets
      f = Findler.new(dir)
      collect_files(f.iterator).sort.must_equal `find * -type f -not -name '.*'`.split.sort
      f.exclude_hidden! # should be a no-op
      collect_files(f.iterator).sort.must_equal `find * -type f -not -name '.*'`.split.sort
      f.include_hidden!
      collect_files(f.iterator).sort.must_equal `find . -type f | sed -e 's/^\\.\\///'`.split.sort
    end
  end

  it "should find only .jpg files when constrained" do
    with_tree(%W(.jpg .txt .JPG)) do |dir|
      f = Findler.new(dir)
      f.add_extension ".jpg"
      iter = f.iterator
      collect_files(iter).sort.must_equal `find * -type f -name \\*.jpg`.split.sort
    end
  end

  it "should find .jpg or .JPG files when constrained" do
    with_tree(%W(.jpg .txt .JPG)) do |dir|
      f = Findler.new(dir)
      f.add_extension ".jpg"
      f.case_insensitive!
      iter = f.iterator
      collect_files(iter).sort.must_equal `find * -type f -iname \\*.jpg`.split.sort
    end
  end

  it "should find files added after iteration started" do
    with_tree(%W(.txt)) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      iter.next.wont_be_nil

      # cheating with mtime on the touch doesn't properly update the parent directory ctime,
      # so we have to deal with the second-granularity resolution of the filesystem.
      sleep(1.1)

      FileUtils.touch(dir + "new.txt")
      collect_files(iter).must_include("new.txt")
    end
  end

  it "should find new files after a rescan" do
    with_tree([".txt", ".no"]) do |dir|
      f = Findler.new(dir)
      f.add_extension ".txt"
      iter = f.iterator
      collect_files(iter).sort.must_equal `find * -type f -iname \\*.txt`.split.sort
      FileUtils.touch(dir + "dir-0" + "dir-1" + "new-0.txt")
      FileUtils.touch(dir + "dir-1" + "dir-0" + "new-1.txt")
      FileUtils.touch(dir + "dir-2" + "dir-2" + "new-2.txt")
      collect_files(iter).must_be_empty
      iter.rescan!
      collect_files(iter).sort.must_equal ["dir-0/dir-1/new-0.txt", "dir-1/dir-0/new-1.txt", "dir-2/dir-2/new-2.txt"]
    end
  end

  it "should not return files removed after iteration started" do
    with_tree([".txt"]) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      iter.next.wont_be_nil
      sleep(1.1) # see above for hand-wringing-defense of this atrocity

      (dir + "tmp-1.txt").unlink
      collect_files(iter).wont_include("tmp-1.txt")
    end
  end

  it "should dump/load in the middle of iterating" do
    with_tree(%W(.jpg .txt .JPG)) do |dir|
      all_files = `find * -type f -iname \\*.jpg`.split
      all_files.size.times do |i|
        f = Findler.new(dir)
        f.add_extension ".jpg"
        f.case_insensitive!
        iter_a = f.iterator
        files_a = i.times.collect { relative_path(iter_a.path, iter_a.next) }
        iter_b = Marshal.load(Marshal.dump(iter_a))
        files_b = collect_files(iter_b)

        iter_c = Marshal.load(Marshal.dump(iter_b))
        collect_files(iter_c)
        iter_c.next.must_be_nil

        (files_a + files_b).sort.must_equal all_files.sort
      end
    end
  end

  it "should create an iterator even for a non-existent directory" do
    tmpdir = nil
    Dir.mktmpdir do |dir|
      tmpdir = Pathname.new dir
    end
    tmpdir.exist?.must_equal false
    f = Findler.new(tmpdir)
    collect_files(f.iterator).must_be_empty
  end

  it "should raise an error if the block given to next returns nil" do
    Dir.mktmpdir do |dir|
      f = Findler.new(dir)
      f.add_filter :no_return
      i = f.iterator
      lambda { i.next }.must_raise(Findler::Error)
    end
  end

  it "should raise an error if the block returns non-children" do
    with_tree(%W(.txt)) do |dir|
      f = Findler.new(dir)
      f.add_filter :invalid_return
      i = f.iterator
      lambda { i.next }.must_raise(Findler::Error)
    end
  end

  it "should support filter_with against global/Kernel methods" do
    with_tree(%W(.txt)) do |dir|
      f = Findler.new(dir)
      f.add_filter :files_to_s
      iter = f.iterator
      files = collect_files(iter)
      files.sort.must_equal `find * -type f`.split.sort
    end
  end

  it "should support next blocks properly" do
    with_tree(%W(.a .b)) do |dir|
      Dir["**/*.a"].each { |ea| File.open(ea, 'w') { |f| f.write("hello") } }
      f = Findler.new(dir)
      f.add_filter :non_empty_files
      iter = f.iterator
      files = collect_files(iter)
      files.sort.must_equal `find * -type f -name \\*.a`.split.sort
    end
  end
end
