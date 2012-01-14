# Findler, your friendly neighborhood filesystem iterator with persistable state

Findler is a Ruby library for iterating over a filtered set of files in a given
set of paths, suitable concurrent workers and very large filesystem enumerations.

## Usage

```ruby
f = Findler.new "/Users/mrm"
f.append_extension ".jpg", ".jpeg"
f.append_paths "My Pictures", "Photos"
iterator = f.iterator
iterator.next
# => "/Users/mrm/Photos/IMG_1000.JPG"
```

## Cross-process continuations

This should smell an awful lot like [hike](https://github.com/sstephenson/hike),
except for that last bit.

```Findler.iterator``` instances can be "paused" and "resumed" with ```to_json```.
The entire state of the iteration for the filesystem is returned, which can then
be pushed onto any durable storage, like ActiveRecord or Redis.
```ruby
File.open('state.json', 'w') { |f| f.write(iterator.to_json) }
```

To resume iteration, use ```Findler.iterator_from_json", and continue iterating:
```ruby
Findler.iterator_from_json(IO.open('state.json'))
iterator.next
# => "/Users/mrm/Photos/IMG_1001.JPG"
```
