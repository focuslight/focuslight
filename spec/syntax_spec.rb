require_relative './spec_helper'

describe Focuslight do
  it 'has modules that passes syntax check' do
    Dir.glob(__dir__ + '/../lib/**/*.rb').each do |file|
      require file
    end
  end
end
