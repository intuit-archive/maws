require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/instance'

describe 'Instance::RDS' do
  describe "when syncing" do
    pending "is not synced initially"
    pending "is 'non-existant' before syncing"
    pending "syncs description and aws_id"
    pending "is 'existent' after syncing"
  end

  describe "when resyncing"
    pending "updates descriptions and aws_id when the server changes"
    pending "becomes 'non-existent' when the instance disappears from the server"
  end
end