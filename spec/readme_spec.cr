require "./spec_helper"
require "./user.pb"

private def tree(dir, level = 0, io = IO::Memory.new, prefix = "")
  indent = ("    " * [level-1,0].max) + (level > 0 ? " +- " : "")
  if File.directory?(dir)
    io.puts "%s%s%s/" % [prefix, indent, File.basename(dir)]
  elsif File.exists?(dir)
    io.puts "%s%s%s" % [prefix, indent, File.basename(dir)]
  end
  if File.directory?(dir)
    Dir.children(dir).sort.each do |file|
      tree(File.join(dir, file), level: level + 1, io: io, prefix: prefix)
    end
  end
end

private macro execute(cmd)
  log.puts {{cmd.stringify}}
  {{cmd}}
  tree "users", io: log, prefix: "# "
  log.puts
end

describe "README.md" do
  it "### House Directories" do
    log = IO::Memory.new

    user1 = User.new(name: "risa")
    user2 = User.new(name: "pon")
    user3 = User.new(name: "neru")

    Pretty.rm_rf("users")

    execute  house = Protobuf::House(User).new("users")
    execute  house.tmp(user1, {"status" => "writing user1"})
    execute  house.commit({"status" => nil})
    execute  house.tmp(user2, {"status" => "writing user2"})
    execute  house.commit({"status" => nil})
    execute  house.meta({"done" => "true"})

    expect( log.to_s.strip ).to eq README.code("### House Directories")
    Pretty.rm_rf("users")
  end
end
