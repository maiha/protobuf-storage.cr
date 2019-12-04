# protobuf-storage.cr [![Build Status](https://travis-ci.org/maiha/protobuf-storage.cr.svg?branch=master)](https://travis-ci.org/maiha/protobuf-storage.cr)

A handy local storage of Protobuf for [Crystal](http://crystal-lang.org/).

This is suitable for easily providing persistence to protobuf data by `save` and `load`, thus speed is not a top priority.

```crystal
db = Protobuf::Storage(User).new("tmp/users.pb")
db.save(user1)
db.save(user2)

users = Protobuf::Storage(User).load("tmp/users.pb")
users.size # => 2
```

- crystal: 0.30.1, 0.31.1

## API

```crystal
Protobuf::Storage(T).load(path : String) : Array(T)
Protobuf::Storage(T).new(path : String)

Protobuf::Storage(T)
  def clue : String
  def load : Array(T)
  def save(records : Array(T))
  def save(record : T)
  def write(records : Array(T))
  def clean
```

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  protobuf-storage:
    github: maiha/protobuf-storage.cr
    version: 0.3.2
```

This depends `maiha/protobuf.cr` that is a fork of `jeromegn/protobuf.cr`
for adding `Protobuf::Message#[](key)`.

## Restriction about `*.proto`

`Protobuf::Storage` persists the `XXX` protobuf class as a `XXXArray` class.
This class definition needs to be prepared by the user.

For example, when you declare `User`, you must declare `UserArray` too as follows.

```protobuf
message User {
  required string name = 1;
}

// Add the following lines too.
message UserArray {
  repeated User array = 1;
}
```

This would be converted to [user.pb.cr](./spec/user.pb.cr).

## Usage

```crystal
require "protobuf-storage"
```

### Basic example with FILE mode

```crystal
user1 = User.new(name: "risa")
user2 = User.new(name: "pon")

s = Protobuf::Storage(User).new("users.pb")
s.save(user1)      # creates "users.pb"
s.save(user2)      # appends to "users.pb"
s.load.map(&.name) # => ["risa", "pon"]

users = Protobuf::Storage(User).load("users.pb")
users.map(&.name)  # => ["risa", "pon"]
```

```console
$ hd users.pb
00000000  0a 06 0a 04 72 69 73 61  0a 05 0a 03 70 6f 6e     |....risa....pon|
0000000f
```

```crystal
s.load.size      # => 2

s.write([user1]) # replaces "users.pb" with the given data
s.load.size      # => 1

s.clean          # removes "users.pb"
s.load.size      # => 0 (even if the file doesn't exist.)
```

### FILE mode (gzip)

When the filename ends with ".gz" or `gzip: true` option is specified,
it automatically works with `gzip`.

```crystal
s = Protobuf::Storage(User).new("users.pb.gz")
# s = Protobuf::Storage(User).new("users.pb.gz", gzip: true)
s.save([user1, user2])
Protobuf::Storage(User).load("users.pb.gz").size # => 2
```

```console
$ file users.pb.gz
users.pb.gz: gzip compressed data, ...
```

### DIR mode

When the filename ends with "/", it works with multiple files.
In this mode, a new file is added each time `save` is executed.

```crystal
s = Protobuf::Storage(User).new("users/")
s.save(user1) # creates "users/00001.pb"
s.save(user2) # creates "users/00002.pb"

Protobuf::Storage(User).load("users/").size # => 2
```

```console
$ tree users
users
├── 00001.pb
└── 00002.pb
```

### DIR mode (gzip)

We can use `gzip` option in this mode too.

```crystal
s = Protobuf::Storage(User).new("users/", gzip: true)
s.save([user1, user2])
Protobuf::Storage(User).load("users/").size # => 2
```

```console
$ tree users
 users
 └── 00001.pb.gz
```

### logger

```crystal
logger = Logger.new(STDOUT).tap(&.level = Logger::DEBUG)
s = Protobuf::Storage(User).new("users/", logger: logger)
s.save([user1, user2])
s.load
```

```text
D, [2018-09-10 03:04:42 +09:00 #12405] DEBUG -- : [PB] User(/tmp/users).save: 2 records
D, [2018-09-10 03:04:42 +09:00 #12405] DEBUG -- : [PB] User(/tmp/users).save: 2 records (0.0 sec)
D, [2018-09-10 03:04:42 +09:00 #12405] DEBUG -- : [PB] User(/tmp/users).load
D, [2018-09-10 03:04:42 +09:00 #12405] DEBUG -- : [PB] User(/tmp/users).load # => 2
```

## House

`Protobuf::House(T)` is a high level API that consists of metadata and data storage and tmp storage. This provides transaction-ish operations.

```crystal
Protobuf::House(T).new(dir : String, schema : String? = nil, logger : Logger? = nil, watch : Pretty::Stopwatch? = nil)

Protobuf::House(T)
  # storage
  def load                       : Array(T)
  def save(records, meta = nil)  : Storage(T)
  def write(records, meta = nil) : Storage(T)

  # transaction
  def tmp(records, meta = nil)   : Storage(T)
  def commit(meta = nil)         : House(T)
  def meta(meta : Hash)          : House(T)
  def clean                      : House(T)
  def dirty?                     : Bool

  # job
  def checkin(value)             : House(T)
  def checkout                   : String?
  def resume?                    : String?

  # meta data
  def count                      : Int32
  def schema?                    : String?
  def schema                     : String

  # core
  def chdir(new_dir)             : House(T)
  def clue                       : String
```

### House Directories

```crystal
house = Protobuf::House(User).new("users")

house.tmp(user1, {"status" => "writing user1"})
# users/
#  +- meta/
#      +- status
#  +- tmp/
#      +- 00001.pb.gz

house.commit({"status" => nil})
# users/
#  +- data/
#      +- 00001.pb.gz
#  +- meta/

house.tmp(user2, {"status" => "writing user2"})
# users/
#  +- data/
#      +- 00001.pb.gz
#  +- meta/
#      +- status
#  +- tmp/
#      +- 00001.pb.gz

house.commit({"status" => nil})
# users/
#  +- data/
#      +- 00001.pb.gz
#  +- meta/

house.meta({"done" => "true"})
# users/
#  +- data/
#      +- 00001.pb.gz
#  +- meta/
#      +- done
```

### House Meta Count

`House#count` returns the number of data cached in the meta data.
When the amount of data is large, it works faster than `load.size`.

```crystal
house.count       # => 0
house.save(user1)
house.count       # => 1
```

### House Meta Schema

`House#schema` returns the schema string from argument and persisted meta directory.
This is a feature for preserving schema strings, but does not validate the contents.

```crystal
house = Protobuf::House(User).new(path, schema: "message User { string name = 1; }")
house.save(user1)

house = Protobuf::House(User).new(path)
house.schema # => "message User { string name = 1; }"
```

### House Persisted Job

`checkin` and `resume?` provide a simple persisted job.
For example, imagine a job that calls api with ids from 'a' to 'z'.
We can make the job persisted and idempotent easily.

```crystal
full_ids = ("a" .. "z")

# resume suspended job
if id = house.resume?
  rest_ids = (id .. "z")
else
  rest_ids = full_ids
end

# main job
full_ids.each do |id|
  house.checkin(id)
  api_call(id)
end

# clear job
house.checkout
```

#### `checkin(value, group)`, `resume?(group)`

**group** can be used as checksum.

## Contributing

1. Fork it (<https://github.com/maiha/protobuf-storage.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [maiha](https://github.com/maiha) maiha - creator, maintainer
