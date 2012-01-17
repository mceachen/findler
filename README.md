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

```Findler.iterator``` instances can be "paused" and "resumed" with ```to_yaml```.
The entire state of the iteration for the filesystem is returned, which can then
be pushed onto any durable storage, like ActiveRecord or Redis, or just a local file:

```ruby
File.open('state.yaml', 'w') { |f| f.write(iterator.to_yaml) }
```

To resume iteration:

```ruby
Findler::Iterator.from_yaml(IO.open('state.yaml'))
iterator.next
# => "/Users/mrm/Photos/img_1001.jpg"
```