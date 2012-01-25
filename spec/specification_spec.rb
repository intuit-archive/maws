require 'spec/spec_helper'
require 'maws/specification'

describe 'Specification' do
  it "parses index ranges" do
    Specification.new(config, '*').indexes_range_for_role('app').should == [nil, '*']
    Specification.new(config, ' * ').indexes_range_for_role('app').should == [nil, '*']

    Specification.new(config, '').indexes_range_for_role('app').should == [nil, nil]
    Specification.new(config, ' ').indexes_range_for_role('app').should == [nil, nil]

    Specification.new(config, 'a * b').indexes_range_for_role('app').should == [nil, '*']
    Specification.new(config, 'c *').indexes_range_for_role('app').should == [nil, '*']

    Specification.new(config, 'a ').indexes_range_for_role('app').should == [nil, nil]
    Specification.new(config, 'b c').indexes_range_for_role('app').should == [nil, nil]

    Specification.new(config, 'app').indexes_range_for_role('app').should == [nil, nil]
    Specification.new(config, 'app-').indexes_range_for_role('app').should == [nil, nil]
    Specification.new(config, 'app-*').indexes_range_for_role('app').should == [nil, '*']
    Specification.new(config,  'app-3').indexes_range_for_role('app').should == [3,3]
    Specification.new(config, 'app-3-').indexes_range_for_role('app').should ==  [3, nil]
    Specification.new(config, 'app-3-*').indexes_range_for_role('app').should == [3, '*']
    Specification.new(config, 'app-1-3').indexes_range_for_role('app').should == [1, 3]

    Specification.new(config, ' app ').indexes_range_for_role('app').should == [nil, nil]
    Specification.new(config, 'a app-3-* b').indexes_range_for_role('app').should == [3, '*']
    Specification.new(config, ' app-3-* ').indexes_range_for_role('app').should == [3, '*']
  end

  it "ignores bad index ranges" do
    Specification.new(config, "ap").indexes_range_for_role('app').should be_nil
    Specification.new(config, "apps").indexes_range_for_role('app').should be_nil
    Specification.new(config, "lapp").indexes_range_for_role('app').should be_nil
    Specification.new(config, "app-a").indexes_range_for_role('app').should be_nil

    Specification.new(config, " ap ").indexes_range_for_role('app').should be_nil
    Specification.new(config, " apps ").indexes_range_for_role('app').should be_nil
    Specification.new(config, " lapp ").indexes_range_for_role('app').should be_nil
    Specification.new(config, " app-a ").indexes_range_for_role('app').should be_nil
  end

  it "parses zones" do
    Specification.new(config, "").zones.should == %w(a b c)
    Specification.new(config, "*").zones.should == %w(a b c)

    Specification.new(config, "  ").zones.should == %w(a b c)
    Specification.new(config, " * ").zones.should == %w(a b c)


    Specification.new(config, "a").zones.should == %w(a)
    Specification.new(config, "ab").zones.should == %w(a b c)
    Specification.new(config, " aa c bb ").zones.should == %w(c)
  end

  def config
    mash(:available_zones => %w(a b c))
  end
end
