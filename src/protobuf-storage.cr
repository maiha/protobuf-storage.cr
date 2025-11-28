{% if compare_versions(Crystal::VERSION, "0.36.0-0") >= 0 %}
  require "compress/gzip"
  require "logger"
{% else %}
  require "gzip/gzip"
  require "logger"
{% end %}
require "protobuf"
require "pretty"
require "var"

require "./ext/*"
require "./protobuf/*"
