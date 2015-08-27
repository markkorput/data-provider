require File.dirname(__FILE__) + '/spec_helper'

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

  let(:provider){
    ArrayProviderClass.new
  }

  it "lets you use array as provider identifiers" do
    expect(provider.take([:some, 'Stuff'])).to eq 'SomeStuff'
  end

  it "lets you overwrite existing providers with Array-based identifiers" do
    expect(provider.take([:some, 'Stuff'])).to eq 'SomeStuff'
    provider.class.add(ArrayProviderModule)
    # class got updated
    expect(provider.class.new.take([:some, 'Stuff'])).to eq 'OtherStuff'
    # already instatiated instances didn't get this memo
    expect(provider.take([:some, 'Stuff'])).to eq 'SomeStuff'
  end
end

describe "mixing regular ruby methods and data providers" do
  module MixedModule
    include DataProvider::Base

    def func2
      "More Normal Stuff"
    end

    provider :module_provider do
      "#{take(:pro_vider)}, #{func}, #{func2}"
    end
  end

  class MixedClass
    include DataProvider::Base

    provider :pro_vider do
      func
    end

    def func
      "Something Normal Here"
    end

    add MixedModule
  end

  describe "custom class methods" do
    it "does not let providers access regular methods" do
      obj = MixedClass.new
      expect(obj.func).to eq 'Something Normal Here'
      expect(obj.take(:pro_vider)).to eq 'Something Normal Here'
    end

    it "does not let module providers access methods from the base class or vice-versa" do
      obj = MixedClass.new
      expect(obj.func2).to eq 'More Normal Stuff'
      expect(obj.take(:module_provider)).to eq 'Something Normal Here, Something Normal Here, More Normal Stuff'
    end
  end
end

describe "Exceptions" do
  class ExceptionProvider
    include DataProvider::Base

    provider :runtime do
      raise 'Whoops'
    end

    provider :missing do
      take(:foo)
    end

    provider :nomethod do
      bar
    end
  end

  let(:provider){
    ExceptionProvider.new
  }

  it "can go wrong, like everything else" do
    expect { provider.take(:runtime)}.to raise_error(RuntimeError)
    expect { provider.take(:runtime)}.to raise_error('Whoops')
  end

  it "can take from missing providers" do
    expect { provider.take(:missing) }.to raise_error(DataProvider::ProviderMissingException)
    expect { provider.take(:missing) }.to raise_error { |error|
      expect( error.message ).to eq 'Tried to take data from missing provider: :foo'
      expect( error.provider_id ).to eq :foo
    }
  end

  it "can call missing methods" do
    expect { provider.take(:nomethod) }.to raise_error(NameError)
  end
end