require File.dirname(__FILE__) + '/spec_helper'

describe DataProvider::Base do
  # Example implementation of DataProvider::Base
  class ProviderClass
    include DataProvider::Base

    provider :sum, :requires => [:array] do
      sum = 0

      given(:array).each do |number|
        sum += number.to_i
      end

      sum
    end

    provider :static do
      'StaticValue'
    end
  end

  before :all do
    @provider = ProviderClass.new(:data => {:array => [1,2,4]})
  end

  describe "#has_provider?" do
    it 'provides the has_provider? method' do
      expect(@provider.has_provider?(:sum)).to be true
      expect(@provider.has_provider?(:static)).to be true
      expect(@provider.has_provider?(:modulus)).to be false
    end
  end

  describe "#take" do
    it 'lets you take data from it' do
      expect(@provider.take(:sum)).to eq 7
      expect(@provider.take(:static)).to eq 'StaticValue'
    end

    it 'raise a ProviderMissingException when attempting to take from unknown provider' do
      expect{@provider.take(:unknown)}.to raise_error(DataProvider::ProviderMissingException)
    end
  end

  describe "#give" do
    it "lets you give data, creating a new data provider instance" do
      updated_provider = @provider.give :array => [1,80]
      expect(@provider.take(:sum)).to eq 7
      expect(updated_provider.take(:sum)).to eq 81
    end

    it "allows for linked notation" do
      expect(@provider.give(:array => [7, -3]).take(:sum)).to eq 4
    end

    it "has an add_scope alias" do
      expect(@provider.add_scope(:array => [400, 20]).take(:sum)).to eq 420
    end

    it "has an add_data alias" do
      expect(@provider.add_data(:array => [400, 20]).take(:sum)).to eq 420
    end
  end

  describe "#give!" do
    it "lets you update the current provider with additional data" do
      provider = ProviderClass.new(:data => {:array => [1,1,90]})
      expect(provider.take(:sum)).to eq 92
      provider.give!(:array => [3,90])
      expect(provider.take(:sum)).to eq 93
    end

    it "allows for linked notation" do
      expect(@provider.give.give!(:array => [-1, -4]).take(:sum)).to eq -5
    end

    it "has an add_scope! alias" do
      provider = @provider.add_scope()
      provider.add_scope!(:array => [-1, -4])
      expect(provider.given(:array)).to eq [-1,-4]
      expect(provider.take(:sum)).to eq -5
    end

    it "has an add_data! alias" do
      scoped_provider = @provider.add_data(:array => []).add_data!(:array => [5, 5])
      expect(scoped_provider.get_data(:array)).to eq [5,5]
      expect(scoped_provider.take(:sum)).to eq 10
    end
  end

  describe "#given" do 
    it "has a given method to get given data" do
      expect(@provider.given(:array)).to eq [1,2,4]
      expect(@provider.give(:array => 'array').given(:array)).to eq 'array'
    end

    it "has a get_data alias" do
      expect(@provider.get_data(:array)).to eq @provider.given(:array)
    end
  end
end

describe "Adding additional providers" do
  module AdditionalProvider
    include DataProvider::Base

    provider 'provider2' do
      '#2'
    end
  end

  module OverwriteProvider
    include DataProvider::Base

    provider 'provider1' do
      '#111'
    end
  end

  class OriginalProvider
    include DataProvider::Base

    provider 'provider1' do
      '#1'
    end

    add AdditionalProvider
    add OverwriteProvider
  end

  it "lets you include modules with additional providers" do
    expect(OriginalProvider.new.take('provider2')).to eq '#2'
  end

  it "lets you include modules with additional providers" do
    expect(OriginalProvider.new.take('provider1')).to eq '#111'
  end
end

describe "Array identifiers" do
  module ArrayProviderModule
    include DataProvider::Base

    provider [:some, 'Stuff'] do
      'OtherStuff'
    end
  end

  class ArrayProviderClass
    include DataProvider::Base

    provider [:some, 'Stuff'] do
      'SomeStuff'
    end

    # add ArrayProviderModule
  end

  before :all do
    @provider = ArrayProviderClass.new
  end

  it "lets you use array as provider identifiers" do
    expect(@provider.take([:some, 'Stuff'])).to eq 'SomeStuff'
  end

  it "lets you overwrite existing providers with Array-based identifiers" do
    # skip 'not working yet'
    provider = ArrayProviderClass.new
    expect(provider.take([:some, 'Stuff'])).to eq 'SomeStuff'

    provider.class.add(ArrayProviderModule)
    expect(provider.take([:some, 'Stuff'])).to eq 'OtherStuff'
  end
end