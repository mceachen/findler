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

  it "should dump/load properly before iteration" do
    with_tree([".jpg", ".txt", ".JPG"]) do |dir|
      f = Findler.new(dir)
      f.append_extension ".jpg"
      f.case_insensitive!
      iter = f.iterator
      first = iter.next
      first.should_not be_nil
      data = Marshal.dump(iter)
      new_iter = Marshal.load(data)
      collect_files(new_iter).should =~ (`find * -type f -iname \\*.jpg`.split - [first.relative_path_from(dir).to_s])
    end
  end

  it "should dump/load in the middle of iteration"
  it "should dump/load after iteration"
  it "should create an iterator even for a non-existent directory"

end
