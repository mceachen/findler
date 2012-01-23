require 'rspec'
require 'tmpdir'
require 'fileutils'
require 'findler'

RSpec.configure do |config|
  config.color_enabled = true
  config.formatter = 'documentation'
end

def with_tmp_dir(&block)
  cwd = Dir.pwd
  Dir.mktmpdir do |dir|
    Dir.chdir(dir)
    yield(Pathname.new dir)
  end
  Dir.chdir(cwd)
end

def with_tree(sufficies, &block)
  with_tmp_dir do |dir|
    sufficies.each { |suffix| mk_tree dir, @opts.merge(:suffix => suffix) }
    yield(dir)
  end
end

def mk_tree(target_dir, options)
  opts = {
    :depth => 3,
    :files_per_dir => 3,
    :subdirs_per_dir => 3,
    :prefix => "tmp",
    :suffix => "",
    :dir_prefix => "dir",
    :dir_suffix => ""
  }.merge options
  p = target_dir.is_a?(Pathname) ? target_dir : Pathname.new(target_dir)
  p.mkdir unless p.exist?

  opts[:files_per_dir].times do |i|
    fname = "#{opts[:prefix]}-#{i}#{opts[:suffix]}"
    FileUtils.touch(p + fname).to_s
  end
  return if (opts[:depth] -= 1) <= 0
  opts[:subdirs_per_dir].times do |i|
    dir = "#{opts[:dir_prefix]}-#{i}#{opts[:dir_suffix]}"
    mk_tree(p + dir, opts)
  end
end

def expected_files(depth, files_per_dir, subdirs_per_dir)
  return 0 if depth == 0
  files_per_dir + (subdirs_per_dir * expected_files(depth - 1, files_per_dir, subdirs_per_dir))
end

def relative_path(parent, pathname)
  pathname.relative_path_from(parent.path).to_s
end

def collect_files(iter)
  files = []
  while nxt = iter.next
    files << relative_path(iter, nxt)
  end
  files
end
