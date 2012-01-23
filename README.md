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


## Changelog

* 0.0.1 First `find`
* 0.0.2 Added scalable Bloom filter so ```Iterator#rescan``` is possible
* 0.0.3 Fixed gemfile packaging