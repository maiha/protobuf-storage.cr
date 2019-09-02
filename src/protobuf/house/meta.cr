class Protobuf::House(T)
  class Meta
    SYSTEM_KEYS = ["count"]
    
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
      self[key]? || raise ArgumentError.new("No meta data: #{key.inspect}")
    end

    def []=(key : String, val : String?, force : Bool = false)
      if SYSTEM_KEYS.includes?(key) && force == false
        raise ArgumentError.new("'#{key}' is system reserved")
      end

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

  def meta(meta : Hash(String, String?)?) : House(T)
    @meta.update(meta)
    return self
  end
end
