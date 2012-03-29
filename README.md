# Findler: Filesystem Iteration with Persistable State

[![Build Status](https://secure.travis-ci.org/mceachen/findler.png?branch=master)](http://travis-ci.org/mceachen/findler)

Findler is a Ruby library for iterating over a filtered set of files from a given
path, written to be suitable with concurrent workers and very large
filesystem hierarchies.

## Usage

```ruby
f = Findler.new "/Users/mrm"
f.add_extensions ".jpg", ".jpeg"
iterator = f.iterator
iterator.next_file
# => "/Users/mrm/Photos/img_1000.jpg"
```

## Cross-process continuations

This should smell an awful lot like [hike](https://github.com/sstephenson/hike),
except for that last bit.

```Findler::Iterator``` instances can be "paused" and "resumed" with ```Marshal```.
The entire state of the iteration for the filesystem is returned, which can then
be pushed onto any durable storage, like ActiveRecord or Redis, or just a local file:

```ruby
File.open('iterator.state', 'w') { |f| Marshal.dump(iterator, f) }
```

To resume iteration:

```ruby
Marshal.load(IO.open('iterator.state'))
iterator.next_file
# => "/Users/mrm/Photos/img_1001.jpg"
```

To re-check a directory hierarchy for files that you haven't visited yet:

```ruby
iterator.rescan!
iterator.next_file
# => "/Users/mrm/Photos/img_1002.jpg"
```

External synchronization between the serialized state of the
iterator and the other processes will have to be done by you, of course.
The ```load```, ```next_file``` , and ```dump``` should be done while holding
an iteration mutex of some sort.

## Filtering and ordering

Filters provide custom exclusion and ordering criteria, so you don't
have to do that logic in the code that consumes from your iterator.

Filters can't be procs or lambdas because those aren't safely serializable.

What you provide to ```add_filter``` is a symbolized name of a class method
on ```Findler::Filters```:

```ruby
f = Findler.new(".")
f.add_filter :order_by_name
```

Note that the last filter added will be last to order the children, so it will be the
"primary" sort criterion. Note also that the ordering is only done in
the context of a given directory.

### Implementing your own filter

Filter methods receive an array of ```Pathname``` instances. Those pathnames will:

1. have the same parent
2. will not have been enumerated by ```next_file()``` already
3. will satisfy the settings given to the parent Findler instance, like ```include_hidden```
   and added patterns.

Note that the last filter added will be last to order the children, so it will be the
"primary" sort criterion.

The returned values from the class method will be the final set of elements (both files
and directories) that Findler will return from ```next_file()```.

### Example

To find files that have valid EXIF headers, using the *most* excellent
[exiftoolr](https://github.com/mceachen/exiftoolr) gem, you'd do this:

```ruby
require 'findler'
require 'exiftoolr'

# Monkey-patch Filters to add our custom filter:
class Findler::Filters
  def self.exif_only(children)
    child_files = children.select{|ea|ea.file?}
    child_dirs = child_files.select{|ea|ea.directory?}
    e = Exiftoolr.new(child_files)
    e.files_with_results + child_dirs
  end
end

f = Findler.new "/Users/mrm"
f.add_extensions ".jpg", ".jpeg", ".cr2", ".nef"
f.case_insensitive!
f.add_filter(:exif_only)
```

### Filter implementation notes

* The array of ```Pathname``` instances can be assumed to be absolute.
* Only child files that satisfy the ```extension``` and ```pattern``` filters will be seen by the filter class method.
* If a directory doesn't have any relevant files, the filter method will be called multiple times for a given call to ```next_file()```.
* if you want to be notified when new directories are walked into, and you want to do a bulk operation within that directory,
  this gives you that hook–-just remember to return the children array at the end of your block.

### Why can't ```filter_with``` be a proc?

Because procs and lambdas aren't Marshal-able, and I didn't want to use something scary like ruby2ruby and eval.

## Changelog

* 0.0.4 Added custom filters for ```next_file()``` and singular aliases for ```add_extension``` and ```add_pattern```
* 0.0.3 Fixed gemfile packaging
* 0.0.2 Added scalable Bloom filter so ```Iterator#rescan``` is possible
* 0.0.1 First `find`
