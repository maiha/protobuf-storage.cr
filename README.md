# protobuf-storage.cr

A handy local storage of Protobuf for [Crystal](http://crystal-lang.org/).

This is suitable for easily providing persistence to protobuf data by `save` and `load`, thus speed is not a top priority.

```crystal
db = Protobuf::Storage(User).new("tmp/users.pb")
db.save(user1)
db.save(user2)

users = Protobuf::Storage(User).load("tmp/users.pb")
users.size # => 2
```

- crystal: 0.26.1

## API

```crystal
# class methods
Protobuf::Storage(T).load(path : String) : Array(T)
Protobuf::Storage(T).new(path : String)

# instance methods
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
    version: 0.1.0
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

s.clean          # remove "users.pb"
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

## Contributing

1. Fork it (<https://github.com/maiha/protobuf-storage.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [maiha](https://github.com/maiha) maiha - creator, maintainer
