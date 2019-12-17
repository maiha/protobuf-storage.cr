require "spec"
require "spec2"

require "../src/protobuf-storage"

include Spec2::GlobalDSL

class Readme
  def initialize(@path : String)
    @buf = File.read(@path)
  end

  def code(label) : String
    head, body = @buf.split(/^#{label}/m,2)
    body || raise "not found '#{label}' in #{@path}"
    body.scan(/^```.*?\n(.*?)\n```/m) do
      return $1
    end
    raise "not found code within '#{label}' in #{@path}"
  end
end

README = Readme.new(File.join(__DIR__, "../README.md"))
