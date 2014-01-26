require_relative './spec_helper'

require 'focuslight/validator'

describe Focuslight::Validator do
  describe '.validate_single' do
    it 'returns default value as valid value for params without specified key' do
      result = Focuslight::Validator::Result.new
      params = {key1: "1", key2: "2"}
      spec = {default: "0", rule: Focuslight::Validator.rule(:not_blank)}
      Focuslight::Validator.validate_single(result, params, :key3, spec)

      expect(result[:key3]).to eql("0")
    end

    it 'checks and formats about specified single key, that should have single value in params' do
      params = {key1: "1", key2: "2", keyx: "x"}

      result1 = Focuslight::Validator::Result.new
      spec1 = {rule: Focuslight::Validator.rule(:not_blank)}
      Focuslight::Validator.validate_single(result1, params, :key1, spec1)
      Focuslight::Validator.validate_single(result1, params, :key2, spec1)
      Focuslight::Validator.validate_single(result1, params, :keyx, spec1)
      expect(result1.has_error?).to be_false
      expect(result1[:key1]).to eql("1")
      expect(result1[:key2]).to eql("2")
      expect(result1[:keyx]).to eql("x")

      result2 = Focuslight::Validator::Result.new
      spec2 = {rule: [ Focuslight::Validator.rule(:not_blank), Focuslight::Validator.rule(:uint) ]}
      Focuslight::Validator.validate_single(result2, params, :key1, spec2)
      Focuslight::Validator.validate_single(result2, params, :key2, spec2)
      Focuslight::Validator.validate_single(result2, params, :keyx, spec2)
      expect(result2.has_error?).to be_true
      expect(result2[:key1]).to eql(1)
      expect(result2[:key2]).to eql(2)
      expect(result2[:keyx]).to be_nil
      expect(result2.errors).to eql({keyx: "keyx: invalid integer (>= 0)"})
    end
  end

  describe '.validate_array' do
    it 'cannot accept default spec' do
      params = {key1: ["0", "1", "2"], key2: [], key3: ["kazeburo"]}

      result1 = Focuslight::Validator::Result.new
      spec1 = {array: true, default: 1, rule: Focuslight::Validator.rule(:not_blank)}
      expect{ Focuslight::Validator.validate_array(result1, params, :key1, spec1) }.to raise_error(ArgumentError)
    end

    it 'checks array size' do
      params = {key1: ["0", "1", "2"], key2: [], key3: ["kazeburo"]}

      result1 = Focuslight::Validator::Result.new
      spec1 = {array: true, size: 0..3, rule: Focuslight::Validator.rule(:not_blank)}
      Focuslight::Validator.validate_array(result1, params, :key1, spec1)
      Focuslight::Validator.validate_array(result1, params, :key2, spec1)
      Focuslight::Validator.validate_array(result1, params, :key3, spec1)
      expect(result1.has_error?).to be_false
      expect(result1[:key1]).to eql(["0", "1", "2"])
      expect(result1[:key2]).to eql([])
      expect(result1[:key3]).to eql(["kazeburo"])

      result2 = Focuslight::Validator::Result.new
      spec2 = {array: true, size: 1...3, rule: Focuslight::Validator.rule(:not_blank)}
      Focuslight::Validator.validate_array(result2, params, :key1, spec2)
      Focuslight::Validator.validate_array(result2, params, :key2, spec2)
      Focuslight::Validator.validate_array(result2, params, :key3, spec2)
      expect(result2.has_error?).to be_true
      expect(result2[:key1]).to be_nil
      expect(result2[:key2]).to be_nil
      expect(result2[:key3]).to eql(["kazeburo"])
    end

    it 'formats all elements of valid field' do
      params = {key1: ["0", "1", "2"], key2: [], key3: ["kazeburo"]}

      result1 = Focuslight::Validator::Result.new
      spec1 = {array: true, size: 0..3, rule: Focuslight::Validator.rule(:not_blank)}
      Focuslight::Validator.validate_array(result1, params, :key1, spec1)
      Focuslight::Validator.validate_array(result1, params, :key2, spec1)
      Focuslight::Validator.validate_array(result1, params, :key3, spec1)
      expect(result1.has_error?).to be_false
      expect(result1[:key1]).to eql(["0", "1", "2"])
      expect(result1[:key2]).to eql([])
      expect(result1[:key3]).to eql(["kazeburo"])

      result2 = Focuslight::Validator::Result.new
      spec2 = {array: true, size: 0..3, rule: [Focuslight::Validator.rule(:not_blank), Focuslight::Validator.rule(:uint)]}
      Focuslight::Validator.validate_array(result2, params, :key1, spec2)
      Focuslight::Validator.validate_array(result2, params, :key2, spec2)
      Focuslight::Validator.validate_array(result2, params, :key3, spec2)
      expect(result2.has_error?).to be_true
      expect(result2[:key1]).to eql([0, 1, 2])
      expect(result2[:key2]).to eql([])
      expect(result2[:key3]).to be_nil
    end
  end
  describe '.validate_multi_key' do
    it 'does not accept default keyword' do
      params = {key1: "10", key2: "1", key3: "0", key4: "5", key5: "3"}
      result = Focuslight::Validator::Result.new
      spec = { default: 1, rule: Focuslight::Validator::Rule.new(->(x,y,z){ x.to_i + y.to_i + z.to_i < 15 }, "too large") }
      expect{ Focuslight::Validator.validate_multi_key(result, params, [:key1, :key2, :key3], spec) }.to raise_error(ArgumentError)
    end

    it 'checks complex expression with array key (multi field validation)' do
      params = {key1: "10", key2: "1", key3: "0", key4: "5", key5: "3"}
      spec = { rule: Focuslight::Validator::Rule.new(->(x,y,z){ x.to_i + y.to_i + z.to_i < 15 }, "too large") }

      r1 = Focuslight::Validator::Result.new
      Focuslight::Validator.validate_multi_key(r1, params, [:key1, :key2, :key3], spec)
      expect(r1.has_error?).to be_false

      r2 = Focuslight::Validator::Result.new
      Focuslight::Validator.validate_multi_key(r2, params, [:key1, :key2, :key4], spec)
      expect(r2.has_error?).to be_true
      expect(r2.errors).to eql({:'key1,key2,key4' => "key1,key2,key4: too large"})
    end
  end
end
