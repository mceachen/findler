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

  xit "should find files added after iteration started" do
    with_tree([".txt"]) do |dir|
      f = Findler.new(dir)
      iter = f.iterator
      iter.next.should_not be_nil
      FileUtils.touch(dir + "new.txt", :mtime => Time.now - 5)
      collect_files(iter).should include("new.txt")
    end
  end

  it "should not return files removed after iteration started"
  it "should to_yaml/from_yaml before iteration"
  it "should to_yaml/from_yaml in the middle of iteration"
  it "should to_yaml/from_yaml after iteration"
  it "should create an iterator even for a non-existent directory"

end