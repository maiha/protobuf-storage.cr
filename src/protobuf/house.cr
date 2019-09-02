require "./storage"
require "./house/*"

class Protobuf::House(T)
  include Protobuf::Storage::Api(T)

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
    force_update_meta("count", nil) # drop cache
    return @data
  end
  
  def write(records : T | Array(T), meta : Hash(String, String?)? = nil) : Protobuf::Storage(T)
    records = [records] if records.is_a?(T)
    @data.write(records)
    @meta.update(meta)
    force_update_meta("count", records.size.to_s) # drop cache
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
    force_update_meta("count", nil) # drop cache
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

  def count : Int32
    case v = meta["count"]?
    when /^(\d+)$/
      return $1.to_i
    else
      # fall back to load.size
      v = load.size
      force_update_meta("count", v.to_s)
      return v
    end
  end

  def clue : String
    data.clue
  end

  private def force_update_meta(key : String, v : String?)
    meta.try(&.[]=("count", v, force: true))
  end
end
