class Array(T)
  def self.from_protobuf(io : IO)
    new(Protobuf::Buffer.new(io))
  end
  
  def self.new(buf : Protobuf::Buffer)
    array = new
    while true
      tag_id, wire = buf.read_info
      unless (tag_id == nil || tag_id == 1) && (wire == nil || wire == 2)
        raise Protobuf::Error.new("Array(T) expects tag=1 wire=2, but got tag=%s, wire=%s" % [tag_id.inspect, wire.inspect])
      end
      msg = buf.new_from_length || break
      array << T.new(msg)
    end
    array
  end

  def to_protobuf(io : IO)
    buf = Protobuf::Buffer.new(io)
    each do |item|
      buf.write_info(1, 2)
      buf.write_message(item)
    end
  end

  def to_protobuf
    io = IO::Memory.new
    to_protobuf(io)
  end
end
