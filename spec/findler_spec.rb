require 'spec_helper'

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

  it "should find all files by default" do
    with_tree([".jpg", ".txt"]) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      collect_files(iter).should =~ `find * -type f`.split
    end
  end

  it "should find only .jpg files when constrained" do
    with_tree([".jpg", ".txt", ".JPG"]) do |dir|
      f = Findler.new(dir)
      f.append_extension ".jpg"
      iter = f.iterator
      collect_files(iter).should =~ `find * -type f -name \\*.jpg`.split
    end
  end

  it "should find .jpg or .JPG files when constrained" do
    with_tree([".jpg", ".txt", ".JPG"]) do |dir|
      f = Findler.new(dir)
      f.append_extension ".jpg"
      f.case_insensitive!
      iter = f.iterator
      collect_files(iter).should =~ `find * -type f -iname \\*.jpg`.split
    end
  end

  it "should find files added after iteration started" do
    with_tree([".txt"]) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      iter.next.should_not be_nil

      # cheating with mtime on the touch doesn't properly update the parent directory ctime,
      # so we have to deal with the second-granularity resolution of the filesystem.
      sleep(1.1)

      FileUtils.touch(dir + "new.txt")
      collect_files(iter).should include("new.txt")
    end
  end

  it "should find new files after a rescan" do
    with_tree([".txt", ".no"]) do |dir|
      f = Findler.new(dir)
      f.append_extension ".txt"
      iter = f.iterator
      collect_files(iter).should =~ `find * -type f -iname \\*.txt`.split
      FileUtils.touch(dir + "dir-0" + "dir-1" + "new-0.txt")
      FileUtils.touch(dir + "dir-1" + "dir-0" + "new-1.txt")
      FileUtils.touch(dir + "dir-2" + "dir-2" + "new-2.txt")
      collect_files(iter).should be_empty
      iter.rescan!
      collect_files(iter).should =~ ["dir-0/dir-1/new-0.txt", "dir-1/dir-0/new-1.txt", "dir-2/dir-2/new-2.txt"]
    end
  end

  it "should not return files removed after iteration started" do
    with_tree([".txt"]) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      iter.next.should_not be_nil
      sleep(1.1) # see above for hand-wringing-defense of this atrocity

      (dir + "tmp-1.txt").unlink
      collect_files(iter).should_not include("tmp-1.txt")
    end
  end

  it "should dump/load in the middle of iterating" do
    with_tree([".jpg", ".txt", ".JPG"]) do |dir|
      all_files = `find * -type f -iname \\*.jpg`.split
      all_files.size.times do |i|
        f = Findler.new(dir)
        f.append_extension ".jpg"
        f.case_insensitive!
        iter_a = f.iterator
        files_a = i.times.collect { relative_path(iter_a, iter_a.next) }
        iter_b = Marshal.load(Marshal.dump(iter_a))
        files_b = collect_files(iter_b)

        iter_c = Marshal.load(Marshal.dump(iter_b))
        collect_files(iter_c)
        iter_c.next.should be_nil

        (files_a + files_b).should =~ all_files
      end
    end
  end

  it "should create an iterator even for a non-existent directory" do
    tmpdir = nil
    cwd = Dir.pwd
    Dir.mktmpdir do |dir|
      tmpdir = Pathname.new dir
    end
    tmpdir.should_not exist
    f = Findler.new(tmpdir)
    collect_files(f.iterator).should be_empty
  end
end
