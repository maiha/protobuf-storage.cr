require "./spec_helper"
require "./user.pb"

private def build_record(name)
  User.new(name: name)
end

describe "Protobuf::Storage" do
  let(record1) { build_record "1" }
  let(record2) { build_record "2" }
  let(record3) { build_record "3" }
  let(record4) { build_record "4" }

  describe "Mode" do
    it "should be FILE for default" do
      s = Protobuf::Storage(User).new("tmp/foo.pb")
      expect(s.mode).to eq(Protobuf::Storage::Mode::FILE)
    end

    it "should be DIR when the path ends with /" do
      s = Protobuf::Storage(User).new("tmp/foo/")
      expect(s.mode).to eq(Protobuf::Storage::Mode::DIR)
    end
  end

  context "(Mode::FILE)" do
    let(path) { "tmp/spec/lib/proto_storage/User.pb" }
    let(storage) { Protobuf::Storage(User).new(path) }

    it "#clean" do
      storage.clean
      expect(storage.load.size).to eq(0)
    end

    it "#save" do
      storage.clean
      storage.save(record1)
      storage.save([record2, record3])
      storage.save(record4)
      expect(storage.load).to eq([record1, record2, record3, record4])
    end
  end

  context "(Mode::DIR)" do
    let(path) { "tmp/spec/lib/proto_storage/User/" }
    let(storage) { Protobuf::Storage(User).new(path) }

    it "#clean" do
      storage.clean
      expect(storage.load.size).to eq(0)
    end

    it "#save" do
      storage.clean
      storage.save(record1)
      storage.save([record2, record3])
      storage.save(record4)
      expect(storage.load).to eq([record1, record2, record3, record4])
    end
  end

  context "(gzip)" do
    let(path) { "tmp/spec/lib/proto_storage/User/" }
    let(storage) { Protobuf::Storage(User).new(path, gzip: true) }

    it "#clean" do
      storage.clean
      expect(storage.load.size).to eq(0)
    end

    it "#save" do
      storage.clean
      storage.save(record1)
      storage.save([record2, record3])
      storage.save(record4)
      expect(storage.load).to eq([record1, record2, record3, record4])
    end

    it "#load can read data from both plain and gzip files" do
      storage.clean

      storage = Protobuf::Storage(User).new(path)
      storage.save(record1)

      storage = Protobuf::Storage(User).new(path, gzip: true)
      storage.save([record2, record3])
      storage.save(record4)
      expect(storage.load).to eq([record1, record2, record3, record4])
    end
  end
end

private def storage
  Protobuf::Storage(User)
end

describe "Protobuf::Storage(usecase)" do
  describe "load from whole sub directories" do
    let(dir) { "tmp/spec/lib/proto_storage/subdir/User" }
    let(pbs) { (0..9).map{|i| build_record "name#{i}" } }
    let(paths) { ["00001.pb", "1.pb", "2.pb.gz", "3.pb", "45.pb", "6.pb.gz", "seven.pb.gz", "x/8.pb", "y/9/z.pb.gz"] }

    # .
    # |-- 00001.pb
    # |-- 1.pb
    # |-- 2.pb.gz
    # |-- 3.pb
    # |-- 45.pb
    # |-- 6.pb.gz
    # |-- seven.pb.gz
    # |-- x
    # |   `-- 8.pb
    # `-- y
    #     `-- 9
    #         `-- z.pb.gz

    it "delete old files" do
      FileUtils.mkdir_p(dir)
      Dir.cd(File.dirname(dir)) { FileUtils.rm_rf("User") }
    end
    
    it "create fixtures" do
      # save(pb)
      storage.new("#{dir}/").save(pbs[0])
      storage.new("#{dir}/1.pb").save(pbs[1])
      storage.new("#{dir}/2.pb.gz", gzip: true).save(pbs[2])

      # save(Array(pb))
      storage.new("#{dir}/3.pb").save([pbs[3]])
      storage.new("#{dir}/45.pb").save(pbs[4..5])
      storage.new("#{dir}/6.pb.gz", gzip: true).save([pbs[6]])
      storage.new("#{dir}/seven.pb.gz", gzip: true).save([pbs[7]])

      # save into subdir
      FileUtils.mkdir_p("#{dir}/x")
      storage.new("#{dir}/x/8.pb").save(pbs[8])
      FileUtils.mkdir_p("#{dir}/y/9")
      storage.new("#{dir}/y/9/z.pb.gz", gzip: true).save([pbs[9]])
    end

    it "should save pb files correctly" do
      files = Dir.cd(dir) {Dir["**/*"].to_a.reject{|i| File.directory?(i)}}
      expect(files.sort).to eq(paths)
    end

    it "should load from explicitly specifed file" do
      expect(storage.load("#{dir}/00001.pb")).to eq([pbs[0]])
      expect(storage.load("#{dir}/1.pb")).to eq([pbs[1]])
      expect(storage.load("#{dir}/2.pb.gz")).to eq([pbs[2]])

      expect(storage.load("#{dir}/3.pb")).to eq([pbs[3]])
      expect(storage.load("#{dir}/45.pb")).to eq(pbs[4..5])
      expect(storage.load("#{dir}/6.pb.gz")).to eq([pbs[6]])
      expect(storage.load("#{dir}/seven.pb.gz")).to eq([pbs[7]])

      expect(storage.load("#{dir}/x/8.pb")).to eq([pbs[8]])
      expect(storage.load("#{dir}/y/9/z.pb.gz")).to eq([pbs[9]])
    end

    it ".load should load all data from sub directories" do
      found = storage.load(dir)
      expect(found.size).to eq(10)
      expect(found.map(&.name).sort).to eq((0..9).map{|i| "name#{i}"})
    end

    it "#load should load all data from sub directories" do
      found = storage.new(dir).load
      expect(found.size).to eq(10)
      expect(found.map(&.name).sort).to eq((0..9).map{|i| "name#{i}"})
    end

    it "#clean should delete the directory recursively" do
      storage.new("#{dir}/").clean
      expect(File.exists?(dir)).to be_false
    end
  end
end
