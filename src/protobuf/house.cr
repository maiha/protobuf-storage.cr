require "./storage"

class Protobuf::House(T)
  include Protobuf::Storage::Api(T)

  class Meta
    def initialize(@dir : String)
    end

    def each
      open {|dir|
        dir.each_child do |f|
          if File.directory?(f)
            # skip
          else
            yield({f, File.read(f)})
          end
        end
      }
    end

    def []?(key : String) : String?
      open {|dir|
        path = File.join(dir.path, key)
        if File.exists?(path)
          File.read(path)
        else
          nil
        end
      }
    end

    def [](key : String) : String
      self[key]? || raise "No meta data: #{key.inspect}"
    end

    def []=(key : String, val : String?)
      open {|dir|
        path = File.join(dir.path, key)
        if val
          File.write(path, val)
        else
          Pretty.rm_f(path)
        end
      }
    end

    def update(meta : Hash(String, String?)? = nil)
      if hash = meta
        hash.each do |key, val|
          self[key] = val
        end
      end
    end

    def clean
      Pretty.rm_rf(@dir)
    end
    
    private def open
      Pretty.mkdir_p(@dir)
      Dir.open(@dir) {|dir| yield(dir) }
    end
  end

  property meta : Meta
  property data : Protobuf::Storage(T)
  property tmp  : Protobuf::Storage(T)

  property dir    : String
  property logger : Logger

  def initialize(dir : String, gzip : Bool = true, @logger : Logger = Logger.new(nil), watch : Pretty::Stopwatch? = nil)
    @dir  = File.expand_path(dir).chomp("/")

    @meta = Meta.new(File.join(@dir, "meta"))
    @data = Storage(T).new(File.join(@dir, "data"), mode: Storage::Mode::DIR, gzip: gzip, logger: logger, watch: watch)
    @tmp  = Storage(T).new(File.join(@dir, "tmp" ), mode: Storage::Mode::DIR, gzip: gzip, logger: logger, watch: watch)
  end

  def load : Array(T)
    data.load
  end

  def save(records : T | Array(T), meta : Hash(String, String?)? = nil) : Storage(T)
    records = [records] if records.is_a?(T)
    @data.save(records)
    @meta.update(meta)
    return @data
  end
  
  def write(records : T | Array(T), meta : Hash(String, String?)? = nil) : Protobuf::Storage(T)
    records = [records] if records.is_a?(T)
    @data.write(records)
    @meta.update(meta)
    return @data
  end
  
  def tmp(records : T | Array(T), meta : Hash(String, String?)? = nil) : Storage(T)
    records = [records] if records.is_a?(T)
    @tmp.save(records)
    @meta.update(meta)
    return @tmp
  end

  def commit(meta : Hash(String, String?)? = nil) : House(T)
    pbs = @tmp.load
    if pbs.any?
      @data.write(@data.load + pbs)
      @tmp.clean
    end
    @meta.update(meta)
    return self
  end

  def meta(meta : Hash(String, String?)?) : House(T)
    @meta.update(meta)
    return self
  end

  def clean : House(T)
    @data.clean
    @tmp.clean
    @meta.clean
    return self
  end
  
  def dirty? : Bool
    @tmp.load.any?
  end

  def clue : String
    data.clue
  end
end
