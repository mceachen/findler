# Findler, your friendly neighborhood filesystem iterator with persistable state

Findler is a Ruby library for iterating over a filtered set of files in a given
set of paths, suitable concurrent workers and very large filesystem enumerations.

## Usage

```ruby
f = Findler.new "/Users/mrm"
f.append_extension ".jpg", ".jpeg"
f.append_paths "My Pictures", "Photos"
f.case_insensitive!
f.ignore_hidden_files!

iterator = f.iterator
iterator.next
# => "/Users/mrm/Photos/IMG_1234.JPG"
```

## Continuations

This should smell an awful lot like [hike](https://github.com/sstephenson/hike),
except for that last bit.

```Findler.iterator``` instances can be "paused" and "resumed" with ```to_json```.
The entire state of the iteration for the filesystem is returned, which can then
be pushed onto any durable storage, like ActiveRecord or Redis.

To resume iteration, use ```Findler.iterator_from_json", and continue iterating.

