# Findler: Filesystem Iteration with Persistable State

Findler is a Ruby library for iterating over a filtered set of files from a given
path, written to be suitable with concurrent workers and very large
filesystem hierarchies.

## Usage

```ruby
f = Findler.new "/Users/mrm"
f.append_extension ".jpg", ".jpeg"
iterator = f.iterator
iterator.next
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
iterator.next
# => "/Users/mrm/Photos/img_1001.jpg"
```

To re-check a directory hierarchy for files that you haven't visited yet:

```ruby
iterator.rescan!
iterator.next
# => "/Users/mrm/Photos/img_1002.jpg"
```

## Custom filtering

By providing a Class and method symbol to ```Findler.filter_with```, you can
do more advanced file and directory filtering.

When new directories are entered, the block will be passed

1. a ```Pathname``` instance of the new directory, as well as
2. an array of child directories, and
3. an array of child files.

Note that the pre-established filters (based on ```#include_hidden?``` and patterns) will
have already been applied, so if, for example, the file doesn't match any of the provided
patterns, the block won't see that file.

The returned value from the class method will be the final set of elements (both files
and directories) that Findler will return from ```next()```.

### Example

To find files that have valid EXIF headers, using the *most* excellent
[exiftoolr](https://github.com/mceachen/exiftoolr) gem, you'd do this:

```ruby
require 'exiftoolr'

class Filter
  def exif_only(directory, child_dirs, child_files)
    e = Exiftoolr.new(child_files.collect{ |ea| ea.to_s })
    e.files_with_results + child_dirs
  end
end

f = Findler.new "/Users/mrm"
f.append_extension ".jpg", ".jpeg", ".cr2", ".nef"
f.case_insensitive!
f.filter_with(Filter.new.method(:exif_only))
```

### Notes

* the child_dirs and child_files are arrays of ```Pathname```s that you can assume are absolute.
* only child dirs and files that satisfy the ```extension``` and ```pattern``` filters will be seen by the filter class method.
* the block needs to be given to each ```next``` call -- it is not memoized (nor could it be, as it would break Marshalling).
* if a directory is found to be empty, the block will be called multiple times for a given call to ```next()```.
* if you want to be notified when new directories are walked into, and you want to do a bulk operation within that directory,
  this gives you that hook -- just remember to return ```child_dirs + child_files``` at the end of your block.

### Why can't ```filter_with``` be a proc?

Because procs and lambdas aren't Marshal-able, and I didn't want to use something scary like ruby2ruby and eval.

## Changelog

* 0.0.4 Added custom filters for ```next()``` and singular aliases for ```add_extension``` and ```add_pattern```
* 0.0.3 Fixed gemfile packaging
* 0.0.2 Added scalable Bloom filter so ```Iterator#rescan``` is possible
* 0.0.1 First `find`
