## Generated from user.proto
require "protobuf"

struct User
  include Protobuf::Message
  
  contract_of "proto2" do
    required :name, :string, 1
  end
end
