{% if ::Crystal::VERSION =~ /^0\.(1\d|2\d|30)\./ %}
  require "markdown"

  module Crystal::Doc::Markdown
    module Renderer
      include ::Markdown::Renderer
    end

    def self.parse(*args)
      ::Markdown.parse(*args)
    end
  end

{% else %}
  require "compiler/crystal/tools/doc/markdown"
{% end %}

module Crystal::Doc::Markdown
  record Header, level : Int32, text : String do
    def self.parse(text : String)
      level = 1
      case text
      when /^(#+)\s*(.*)$/
        level = $1.to_s.size
        text  = $2
      end
      new(level, text.strip)
    end
  end

  record FencedCodeBlock, code : String, language : String? = nil

  class MemoryRenderer
    include Renderer

    alias Element = Header | FencedCodeBlock
    
    @buffer : IO::Memory? = nil
    @scope : Header? = nil
    @processing_element : Element?

    private property scoped_elements = Hash(Header, Array(Element)).new

    def initialize
      @processing_element = nil
    end

    def code(header : String, index = 0) : String
      header = Header.parse(header)
      elements = @scoped_elements[header]? || raise ArgumentError.new("header not found: #{header.inspect}")
      codes = elements.select(&.is_a?(FencedCodeBlock)).map(&.as(FencedCodeBlock))
      codes[index].code
    end

    def begin_paragraph
    end

    def end_paragraph
    end

    def begin_italic
    end

    def end_italic
    end

    def begin_bold
    end

    def end_bold
    end

    def begin_header(level)      
      @processing_element = Header.new(level, "")
      @buffer = IO::Memory.new
    end

    def end_header(level)
      @processing_element = nil
      if io = @buffer
        @scope = Header.new(level, io.to_s)
      end
    end

    def begin_inline_code
    end

    def end_inline_code
    end

    def begin_code(language)
      @processing_element = FencedCodeBlock.new("", language)
      @buffer = IO::Memory.new
    end

    def end_code
      if header = @scope
        @scoped_elements[header] ||= Array(Element).new
        @scoped_elements[header] << FencedCodeBlock.new(@buffer.to_s)
      end
      @processing_element = nil
    end

    def begin_quote
    end

    def end_quote
    end

    def begin_unordered_list
    end

    def end_unordered_list
    end

    def begin_ordered_list
    end

    def end_ordered_list
    end

    def begin_list_item
    end

    def end_list_item
    end

    def begin_link(url)
    end

    def end_link
    end

    def image(url, alt)
    end

    def text(text)
      case e = @processing_element
      when Header, FencedCodeBlock
        if io = @buffer
          io.print text
        end
      end
    end

    def horizontal_rule
    end
  end
end
