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

  private macro __array__
    {{T.name}}Array
  end

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
    logger.debug "[PB] %s(%s).load" % [T.name, @path]
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

  protected def load_from_file(path) : Array(T)
    array = nil
    File.open(path) do |io|
      case path
      when /\.gz$/
        Gzip::Reader.open(io) do |gzip|
          begin
            buf = gzip.gets_to_end
            io = IO::Memory.new(buf)
          rescue err
            abort "gzip: read error [path='%s']\n%s" % [path, err.to_s]
          end
        end
      end
      array = __array__.from_protobuf(io).array || Array(T).new
    end
    return array.not_nil!
  rescue Errno
    abort "Could not open file '%s': No such file or directory" % path
  end

  # append data
  def save(records : Array(T))
    logger.debug "[PB] %s(%s).save: %d records" % [T.name, @path, records.size]

    process {
      real_path = @path

      case @mode
      when .file?
        records = load.concat(records)
      when .dir?
        real_path = "%s/%05d.pb" % [@path, max_seq_no + 1]
        real_path = "#{real_path}.gz" if @gzip
      end

      File.open(real_path, "w+") do |file|
        if @gzip
          Gzip::Writer.open(file) do |gzip|
            __array__.new(records).to_protobuf(gzip)
          end
        else
          __array__.new(records).to_protobuf(file)
        end
      end
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
