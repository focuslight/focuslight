require_relative './spec_helper'

require 'focuslight/validator'

describe Focuslight::Validator::Rule do
  it 'can be initialized with 2 or 3 arguments' do
    expect{ Focuslight::Validator::Rule.new() }.to raise_error(ArgumentError)
    r1 = Focuslight::Validator::Rule.new(->(v){ v.nil? }, "message")
    r2 = Focuslight::Validator::Rule.new(->(v){ v.nil? }, "message", ->(v){ nil })
    expect{ Focuslight::Validator::Rule.new(->(v){ v.nil? }, "message", ->(v){ nil }, "something") }.to raise_error(ArgumentError)
  end

  describe '#check' do
    it 'can validate value with first argument lambda' do
      r1 = Focuslight::Validator::Rule.new(->(v){ v.nil? }, "only nil")
      expect(r1.check(nil)).to be_truthy
      expect(r1.check("str")).to be_falsey

      r2 = Focuslight::Validator::Rule.new(->(v){ v.to_i == 1 }, "one")
      expect(r2.check("0")).to be_falsey
      expect(r2.check("1.00")).to be_truthy
      expect(r2.check("1")).to be_truthy
      expect(r2.check("2")).to be_falsey
    end

    it 'can receive 2 or more values for lambda arguments if specified' do
      r1 = Focuslight::Validator::Rule.new(->(v1,v2,v3){ v1.to_i > v2.to_i && v2.to_i > v3.to_i }, "order by desc")
      expect(r1.check("1","2","3")).to be_falsey
      expect(r1.check("3","2","1")).to be_truthy
      expect{ r1.check("3") }.to raise_error(ArgumentError)

      r2 = Focuslight::Validator::Rule.new(->(v1){ v1.to_i > 0 }, "greater than zero")
      expect{ r2.check("1", "2") }.to raise_error(ArgumentError)
    end
  end

  describe '#format' do
    context 'when formatter not specified' do
      it 'returns value itself' do
        r = Focuslight::Validator::Rule.new(->(v){ v.size == 3 }, "3chars")
        str = "abc"
        expect(r.format(str)).to equal(str)
      end
    end
    context 'when formatter lambda specified' do
      it 'returns lambda return value' do
        r = Focuslight::Validator::Rule.new(->(v){ v == '0' }, 'zero', ->(v){ 0 })
        expect(r.format("0")).to eql(0)
      end
    end
    context 'when formatter symbol specified' do
      it 'returns value from Symbol.to_proc' do
        r = Focuslight::Validator::Rule.new(->(v){ v == '1' || v == '2' }, 'one or two', :to_i)
        expect(r.format("1")).to eql(1)
        expect(r.format("2")).to eql(2)
      end
    end
  end

  describe '#message' do
    it 'returns predefined message' do
      r = Focuslight::Validator::Rule.new(->(v){ v.nil? }, "nil only allowed")
      expect(r.message).to eql("nil only allowed")
      expect(r.message).to eql("nil only allowed")
      expect(r.message).to eql("nil only allowed")
    end
  end
end
