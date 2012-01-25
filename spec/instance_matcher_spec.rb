require 'spec/spec_helper'
require 'maws/instance_matcher'

describe 'InstanceMatcher' do
  before do
    @instance = mash(:role => 'app', :zone => 'a', :groups => %w(aws))
  end

  it "matches single value filters" do
    InstanceMatcher.matches?(@instance, {:role => 'app'}).should be_true
    InstanceMatcher.matches?(@instance, {:zone => 'a'}).should be_true
    InstanceMatcher.matches?(@instance, {:role => 'app', :zone => 'a'}).should be_true

    InstanceMatcher.matches?(@instance, {:role => 'app', :zone => 'b'}).should_not be_true
  end

  it "matches nil/false as same" do
    instance1 = mash(:role => 'app', :alive? => false)
    instance2 = mash(:role => 'app', :alive? => nil)
    instance3 = mash(:role => 'app', :alive? => true)

    InstanceMatcher.matches?(instance1, {:alive? => false}).should be_true
    InstanceMatcher.matches?(instance1, {:alive? => nil}).should be_true

    InstanceMatcher.matches?(instance2, {:alive? => false}).should be_true
    InstanceMatcher.matches?(instance2, {:alive? => nil}).should be_true

    InstanceMatcher.matches?(instance3, {:alive? => false}).should_not be_true
    InstanceMatcher.matches?(instance3, {:alive? => nil}).should_not be_true
  end

  it "matches multiple value filters" do
    InstanceMatcher.matches?(@instance, {:role => %w(app)}).should be_true
    InstanceMatcher.matches?(@instance, {:role => %w(app web)}).should be_true
    InstanceMatcher.matches?(@instance, {:role => %w(app web), :zone => 'a'}).should be_true
    InstanceMatcher.matches?(@instance, {:role => %w(app web), :zone => ['a']}).should be_true
    InstanceMatcher.matches?(@instance, {:role => %w(app web), :zone => ['a', 'b']}).should be_true

    InstanceMatcher.matches?(@instance, {:role => %w(web)}).should_not be_true
    InstanceMatcher.matches?(@instance, {:role => %w(app web), :zone => 'b'}).should_not be_true
    InstanceMatcher.matches?(@instance, {:role => %w(app), :zone => ['b']}).should_not be_true
  end

  it "matches array values" do
    InstanceMatcher.matches?(@instance, {:groups => 'aws'}).should be_true
    InstanceMatcher.matches?(@instance, {:groups => %w(aws)}).should be_true
    InstanceMatcher.matches?(@instance, {:groups => %w(aws other)}).should be_true

    InstanceMatcher.matches?(@instance, {:groups => 'other'}).should_not be_true
    InstanceMatcher.matches?(@instance, {:groups => %(other)}).should_not be_true
  end

end
