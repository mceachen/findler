require 'minitest/spec'
require 'minitest/reporters'
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'findler'

MiniTest::Reporters.use!

def with_tmp_dir(&block)
  cwd = Dir.pwd
  Dir.mktmpdir do |dir|
    Dir.chdir(dir)
    yield(Pathname.new dir)
    Dir.chdir(cwd) # jruby needs us to cd out of the tmpdir so it can remove it
  end
ensure
  Dir.chdir(cwd)
end

def with_tree(sufficies, options = {}, &block)
  with_tmp_dir do |dir|
    sufficies.each { |suffix| mk_tree dir, options.merge(:suffix => suffix) }
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
  pathname.relative_path_from(parent).to_s
end

def collect_files(iter)
  files = []
  while nxt = iter.next_file
    files << relative_path(iter.path, nxt)
  end
  files
end

def fs_case_sensitive?
  @fs_case_sensitive ||= begin
    `touch CASETEST`
    !File.exist?('casetest')
  ensure
    `rm CASETEST`
  end
end

ALPHANUMERIC = (('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).freeze
def rand_alphanumeric(length = 10)
  (0..length).collect do
    ALPHANUMERIC[rand(ALPHANUMERIC.length)]
  end.join
end
