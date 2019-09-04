require "./spec_helper"
require "./user.pb"

private def build_pb(name)
  User.new(name: name)
end

describe "Protobuf::House" do
  let(path)  { "tmp/spec/lib/proto_house" }
  let(house) { Protobuf::House(User).new(path) }
  let(empty) { Array(String).new }

  let(pb1) { build_pb "1" }
  let(pb2) { build_pb "2" }
  let(pb3) { build_pb "3" }
  
  it "works as Storage" do
    Pretty::Dir.clean(path)
    expect( house                  ).to be_a(Protobuf::Storage::Api(User))
    expect( house.load.size        ).to eq(0)

    expect( house.save(pb1)        ).to eq(house.data)
    expect( house.load.map(&.name) ).to eq(["1"])
    expect( house.save([pb2, pb3]) ).to eq(house.data)
    expect( house.load.map(&.name) ).to eq(["1", "2", "3"])

    expect( house.write([pb2])     ).to eq(house.data)
    expect( house.load.map(&.name) ).to eq(["2"])

    expect( house.clean            ).to eq(house)
    expect( house.load.map(&.name) ).to eq(empty)
  end
    
  it "supports Metadata like Hash(String, String)" do
    Pretty::Dir.clean(path)
    expect( house.meta["running"]? ).to eq(nil)
    expect{ house.meta["running"]  }.to raise_error(Exception)

    house.meta["running"] = "foo"
    expect( house.meta["running"]? ).to eq("foo")
    expect( house.meta["running"]  ).to eq("foo")

    house.meta["running"] = "bar"
    expect( house.meta["running"]? ).to eq("bar")
    expect( house.meta["running"]  ).to eq("bar")

    house.meta["running"] = nil
    expect( house.meta["running"]? ).to eq(nil)
    expect{ house.meta["running"]  }.to raise_error(Exception)
  end

  describe "supports multiple storages: data, tmp" do
    it "(default values)" do
      Pretty::Dir.clean(path)
      expect( house.data                 ).to be_a(Protobuf::Storage(User))
      expect( house.tmp                  ).to be_a(Protobuf::Storage(User))
      expect( house.dirty?               ).to eq(false)
      expect( house.tmp.load.map(&.name) ).to eq(empty)
    end

    it "#commit is NOP when not dirty" do
      expect( house.commit               ).to eq(house)
      expect( house.dirty?               ).to eq(false)
      expect( house.tmp.load.map(&.name) ).to eq(empty)
    end
    
    it "#tmp(pbs) writes into not data but tmp storage" do
      expect( house.tmp(pb1)             ).to eq(house.tmp)
      expect( house.dirty?               ).to eq(true)
      expect( house.tmp.load.map(&.name) ).to eq(["1"])
      expect( house.load.map(&.name)     ).to eq(empty)
    end

    it "#commit moves pbs from tmp to data when not dirty" do
      expect( house.commit               ).to eq(house)
      expect( house.dirty?               ).to eq(false)
      expect( house.tmp.load.map(&.name) ).to eq(empty)
      expect( house.load.map(&.name)     ).to eq(["1"])
    end
    
    it "#save writes to data storage directly" do
      expect( house.save(pb2)        ).to eq(house.data)
      expect( house.dirty?               ).to eq(false)
      expect( house.tmp.load.map(&.name) ).to eq(empty)
      expect( house.load.map(&.name)     ).to eq(["1", "2"])
    end

    it "#tmp accepts metadata too" do
      expect( house.tmp([pb3], {"running" => "writing 3"}) ).to eq(house.tmp)
      expect( house.dirty?               ).to eq(true)
      expect( house.tmp.load.map(&.name) ).to eq(["3"])
      expect( house.meta["running"]?     ).to eq("writing 3")
      expect( house.load.map(&.name)     ).to eq(["1", "2"])
    end

    it "#commit accepts metadata too" do
      expect( house.commit({"running" => nil}) ).to eq(house)
      expect( house.dirty?               ).to eq(false)
      expect( house.tmp.load.map(&.name) ).to eq(empty)
      expect( house.meta["running"]?     ).to eq(nil)
      expect( house.load.map(&.name)     ).to eq(["1", "2", "3"])
    end

    it "#chdir" do
      child = house.chdir(File.join(house.dir, "child"))
      full_path = File.expand_path("tmp/spec/lib/proto_house")
      expect( house.dir ).to eq(full_path)
      expect( child.dir ).to eq(full_path + "/child")
    end
  end

  it "provides suspend and resume" do
    Pretty::Dir.clean(path)

    worker1 = Protobuf::House(User).new(path)
    worker1.tmp([pb1,pb2], {"status" => "running"})

    worker2 = Protobuf::House(User).new(path)
    worker2.tmp([pb3], {"status" => "running"})

    worker3 = Protobuf::House(User).new(path)
    expect( worker3.meta["status"]?  ).to eq("running")
    expect( worker3.load.map(&.name) ).to eq(empty)

    worker3.commit({"status" => nil})
    expect( worker3.meta["status"]?  ).to eq(nil)
    expect( worker3.load.map(&.name) ).to eq(["1", "2", "3"])
  end

  describe "#count" do
    it "returns data count" do
      Pretty::Dir.clean(path)
      house.save(pb1)
      expect( house.count ).to eq(1)

      house.save([pb2, pb3])
      expect( house.count ).to eq(3)

      house.clean
      expect( house.count ).to eq(0)

      house.tmp([pb1, pb2])
      expect( house.count ).to eq(0)

      house.commit
      expect( house.count ).to eq(2)

      house.write(pb1)
      expect( house.count ).to eq(1)
    end

    context "(no meta data)" do
      it "fall back to load.size, and caches it in meta data" do
        Pretty::Dir.clean(path)
        expect( File.exists?("#{path}/meta/count") ).to eq(false)
        expect( house.count                        ).to eq(0)
        expect( File.exists?("#{path}/meta/count") ).to eq(true)
      end
    end

    context "(as meta data)" do
      it "can be read as meta data" do
        Pretty::Dir.clean(path)
        expect( house.meta["count"]? ).to eq(nil)
        expect( house.count          ).to eq(0)
        expect( house.meta["count"]? ).to eq("0")
      end

      it "raises when writing as meta data" do
        expect{ house.meta["count"] = "0" }.to raise_error(ArgumentError)
      end
    end
  end
end
