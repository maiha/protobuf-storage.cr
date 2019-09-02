require "./spec_helper"
require "./user.pb"

describe "Protobuf::House (job)" do
  it "works" do
    house = Protobuf::House(User).new("tmp/spec/lib/proto_house/job")
    house.clean

    expect( house.resume?("foo")        ).to eq(nil)

    expect( house.checkin("foo", "1")   ).to eq(house)
    expect( house.resume?("bar")        ).to eq(nil)
    expect( house.resume?("foo")        ).to eq("1")

    expect( house.checkout              ).to eq("1")
    expect( house.resume?("foo")        ).to eq(nil)

    expect( house.checkout              ).to eq(nil)
    expect( house.resume?("foo")        ).to eq(nil)
  end
end
