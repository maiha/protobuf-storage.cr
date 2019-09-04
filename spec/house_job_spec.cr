require "./spec_helper"
require "./user.pb"

describe "Protobuf::House (job)" do
  it "works" do
    house = Protobuf::House(User).new("tmp/spec/lib/proto_house/job")
    house.clean

    expect( house.resume?        ).to eq(nil)

    expect( house.checkin("1")   ).to eq(house)
    expect( house.resume?        ).to eq("1")
    expect( house.resume?        ).to eq("1")

    expect( house.checkout       ).to eq("1")
    expect( house.resume?        ).to eq(nil)
    expect( house.checkout       ).to eq(nil)
    expect( house.resume?        ).to eq(nil)

    expect( house.checkin("2")   ).to eq(house)
    expect( house.resume?        ).to eq("2")
    expect( house.checkin(nil)   ).to eq(house)
    expect( house.resume?        ).to eq(nil)
  end

  it "works with group" do
    house = Protobuf::House(User).new("tmp/spec/lib/proto_house/job")
    house.clean

    expect( house.resume?("xyz")             ).to eq(nil)

    expect( house.checkin("1", group: "xyz") ).to eq(house)
    expect( house.resume?("foo")             ).to eq(nil)
    expect( house.resume?("xyz")             ).to eq("1")

    expect( house.checkout                   ).to eq("1")
    expect( house.resume?("xyz")             ).to eq(nil)
    expect( house.checkout                   ).to eq(nil)
    expect( house.resume?("xyz")             ).to eq(nil)
  end
end
