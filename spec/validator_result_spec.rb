require_relative './spec_helper'

require 'focuslight/validator'

describe Focuslight::Validator::Result do
  it 'indicate that it has errors or not' do
    r = Focuslight::Validator::Result.new
    expect(r.has_error?).to be_false
    r.error("error 1")
    expect(r.has_error?).to be_true
    expect(r.errors).to eql(["error 1"])
    r.error(["error 2", "error 3"])
    expect(r.has_error?).to be_true
    expect(r.errors).to eql(["error 1", "error 2", "error 3"])
  end

  it 'can contain values like Hash, but keys are symbolized' do
    r = Focuslight::Validator::Result.new
    expect(r[:something]).to be_nil
    r['something'] = 'somevalue'
    expect(r[:something]).to eql("somevalue")
    r[:key1] = "value1"
    expect(r[:key1]).to eql("value1")
    r[:key2] = ["value2", "value2alt"]
    expect(r[:key2]).to eql(["value2", "value2alt"])
  end
end
