require_relative './spec_helper'

require 'focuslight/validator'

describe Focuslight::Validator::Result do
  it 'indicate that it has errors or not' do
    r = Focuslight::Validator::Result.new
    expect(r.has_error?).to be_false
    r.error(:key, "error 1")
    expect(r.has_error?).to be_true
    expect(r.errors).to eql({key: "key: error 1"})
    r.error(:key2, "error 2")
    expect(r.has_error?).to be_true
    expect(r.errors).to eql({key:"key: error 1", key2:"key2: error 2"})
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
