require "spec"
require "spec2"

require "../src/protobuf-storage"
require "./markdown"

include Spec2::GlobalDSL

class Readme
  def initialize(path : String)
    @renderer = Markdown::MemoryRenderer.new
    Markdown.parse(File.read(path), @renderer)
  end

  delegate code, to: @renderer
end

README = Readme.new(File.join(__DIR__, "../README.md"))
