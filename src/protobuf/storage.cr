{% if compare_versions(Crystal::VERSION, "0.36.0-0") >= 0 %}
  alias GzipReader = Compress::Gzip::Reader
  alias GzipWriter = Compress::Gzip::Writer
{% else %}
  alias GzipReader = Gzip::Reader
  alias GzipWriter = Gzip::Writer
{% end %}

class Protobuf::Storage(T)
  module Api(T)
    abstract def clue : String
    abstract def load : Array(T)
    abstract def save(records : Array(T))
    abstract def save(record : T)
    abstract def write(records : Array(T))
    abstract def clean
  end

  include Api(T)

  getter logger
  getter path
  getter mode

  enum Mode
    FILE
    DIR
  end
  
  def initialize(path : String, @mode : Mode = Mode::FILE, @gzip : Bool = false, @logger : Logger = Logger.new(nil), watch : Pretty::Stopwatch? = nil)
    @mode  = Mode::DIR if path =~ %r{/$}
    @gzip  = path.ends_with?(".gz") if @mode.file?
    @path  = File.expand_path(path)
    @watch = watch || Pretty::Stopwatch.new
  end

  def clue : String
    @path
  end

  def load : Array(T)
    array = File.exists?(@path) ? load(@path) : Array(T).new
    logger.debug "[PB] %s(%s).load # => %s" % [T.name, @path, Pretty.number(array.size)]
    return array
  end

  protected def load(path) : Array(T)
    files = Array(String).new
    if Dir.exists?(path)
      Dir["#{path}/**/*"].sort.each do |f|
        if f =~ /\.pb(\.gz)?$/
          files << f
        end
      end
    else
      files << path
    end

    array = Array(T).new
    files.each do |file|
      array.concat load_from_file(file)
    end
    return array
  end

  {% begin %}
  protected def load_from_file(path) : Array(T)
    array = nil
    File.open(path) do |io|
      case path
      when /\.gz$/
        GzipReader.open(io) do |gzip|
          begin
            buf = gzip.gets_to_end
            io = IO::Memory.new(buf)
          rescue err
            raise "gzip: read error [path='%s']\n%s" % [path, err.to_s]
          end
        end
      end
      array = Array(T).from_protobuf(io)
    end
    return array.not_nil!
  rescue err : {{ compare_versions(Crystal::VERSION, "0.34.0-0") > 0 ? "File::Error".id : "Errno".id }}
    raise "Could not open file '#{path}': No such file or directory. [#{err}]"
  end
  {% end %}

  # append data
  def save(records : Array(T))
    process {
      real_path = @path

      case @mode
      when .file?
        records = load.concat(records)
      when .dir?
        real_path = "%s/%05d.pb" % [@path, max_seq_no + 1]
        real_path = "#{real_path}.gz" if @gzip
      end

      write_records(real_path, records)
    }

    logger.debug "[PB] %s(%s).save: %d records (%s)" % [T.name, @path, records.size, @watch.try(&.last)]
  end
 
  def save(record : T)
    save([record])
  end

  def write(records : Array(T))
    clean
    save(records)
  end
  
  def clean
    logger.debug "[PB] %s(%s).clean" % [T.name, @path]
    process {
      case @mode
      when .file?
        File.delete(@path) if File.exists?(@path)
      when .dir?
        FileUtils.rm_rf @path
      end
    }      
  end

  # ensure dir exists, and returns its path
  private def mkdir! : String
    case @mode
    when .file?
      dir = File.dirname(@path)
    when .dir?
      dir = @path
    else
      raise "BUG: Protobuf::Storage got unknown mode: #{@mode}"
    end
    Dir.mkdir_p(dir)
    return dir
  end

  private def process
    mkdir!
    @watch.try(&.start)
    yield
  ensure
    @watch.try(&.stop)
  end

  private def write_records(path : String, records : Array(T), retry_on_utf8_error : Bool = true)
    File.open(path, "w+") do |file|
      if @gzip
        GzipWriter.open(file) do |gzip|
          records.to_protobuf(gzip)
        end
      else
        records.to_protobuf(file)
      end
    end
  rescue ex : ArgumentError | Protobuf::Error
    if retry_on_utf8_error && (ex.message.try(&.includes?("Invalid multibyte sequence")) || ex.message.try(&.includes?("Invalid UTF-8")))
      sanitize_records!(records)
      write_records(path, records, retry_on_utf8_error: false)
    else
      raise ex
    end
  end

  private def sanitize_records!(records : Array(T))
    records.size.times do |i|
      records[i] = sanitize_message(records[i], i)
    end
  end

  private def sanitize_message(msg : T, index : Int32) : T forall T
    msg.to_hash.each do |name, val|
      if val.is_a?(String) && !val.valid_encoding?
        fixed = fix_cesu8(val)
        logger.warn "[PB] sanitized invalid UTF-8: record[#{index}].#{name}: #{val.inspect} -> #{fixed.inspect}"
        msg[name] = fixed
      end
    end
    msg
  end

  # Convert CESU-8 encoded surrogate pairs to proper UTF-8
  private def fix_cesu8(str : String) : String
    bytes = str.bytes
    result = IO::Memory.new
    i = 0

    while i < bytes.size
      byte = bytes[i]

      # Check for CESU-8 surrogate pair: ED [A0-AF] [80-BF] ED [B0-BF] [80-BF]
      if byte == 0xed && i + 5 < bytes.size
        b1, b2 = bytes[i + 1], bytes[i + 2]
        b3, b4, b5 = bytes[i + 3], bytes[i + 4], bytes[i + 5]

        if b1.in?(0xa0..0xaf) && b2.in?(0x80..0xbf) &&
           b3 == 0xed && b4.in?(0xb0..0xbf) && b5.in?(0x80..0xbf)
          # Decode surrogate pair from UTF-8 encoded surrogates
          # UTF-8 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
          high = ((byte.to_i32 & 0x0f) << 12) | ((b1.to_i32 & 0x3f) << 6) | (b2.to_i32 & 0x3f)
          low = ((b3.to_i32 & 0x0f) << 12) | ((b4.to_i32 & 0x3f) << 6) | (b5.to_i32 & 0x3f)
          codepoint = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)

          # Encode as proper UTF-8
          result.write_byte(0xf0_u8 | ((codepoint >> 18) & 0x07).to_u8)
          result.write_byte(0x80_u8 | ((codepoint >> 12) & 0x3f).to_u8)
          result.write_byte(0x80_u8 | ((codepoint >> 6) & 0x3f).to_u8)
          result.write_byte(0x80_u8 | (codepoint & 0x3f).to_u8)

          i += 6
          next
        end
      end

      result.write_byte(byte)
      i += 1
    end

    fixed = String.new(result.to_slice)
    # If still invalid after CESU-8 fix, use scrub as fallback
    fixed.valid_encoding? ? fixed : fixed.scrub
  end

  private def max_seq_no : Int32
    @mode.dir? || raise "max_seq_no expects DIR mode, but invoked in #{@mode}"

    max = 0
    Dir.cd(@path){
      Dir["*"].each do |file|
        case file
        when /^(\d+)\.pb(\.gz)?$/
          max = [max, $1.to_i].max
        end
      end
    }
    return max
  end

  def self.load(path : String) : Array(T)
    new(path).load
  end
end
