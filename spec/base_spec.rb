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

    provider :billy do
      take([:identification, :fullname])
    end

    provider [:identification, :firstname] do
      'Billy'
    end

    provider [:identification, :lastname] do
      'Bragg'
    end

    provider [:identification, :fullname] do
      "#{scoped_take(:firstname)} #{scoped_take(:lastname)}"
    end

    provider [:identification, :identifier] do
      take(:firstname)
    end

    provider :fullname do
      'Stephen William Bragg'
    end

    provider [:identification, :id] do
      take(:fullname)
    end

    provider [:identification, :ID] do
      take(:id)
    end
  end

  let(:provider){
    ProviderClass.new(:data => {:array => [1,2,4]})
  }

  describe "Class level" do
    describe "#has_provider?" do
      it 'tells if the specified provider exists' do
        expect(ProviderClass.respond_to?(:has_provider?)).to eq true
        expect(ProviderClass.has_provider?(:sum)).to eq true
        expect(ProviderClass.has_provider?(:divid)).to eq false
      end
    end

    describe "#has_providers_with_scope?" do
      let(:klass){
        Class.new Object do
          include DataProvider::Base
          provider [:a, :b ,:c]
          provider :unscoped
        end
      }

      it "return true if there are providers defined with an array identifier that start with the given prefix" do
        expect(klass.has_providers_with_scope?(:unscoped)).to eq false
        expect(klass.has_providers_with_scope?(:a)).to eq true
        expect(klass.has_providers_with_scope?([:a, :b])).to eq true
        # scope means prefix, identfier may not be exactly the given array
        expect(klass.has_providers_with_scope?([:a, :b, :c])).to eq false
      end
    end

    describe "#provides" do
      class SimpleProviders
        include DataProvider::Base
        provides({
          :name => 'Paddy',
          'instrument' => :bass,
        })
      end

      it "lets you request all currently available simple providers when called without a parameter" do
        expect(SimpleProviders.provides).to eq({
          :name => 'Paddy',
          'instrument' => :bass
        })
      end

      it "lets you define simple providers" do
        expect(SimpleProviders.new.take(:name)).to eq 'Paddy'
        expect(SimpleProviders.new.take('instrument')).to eq :bass
      end

      it "works with has_provider?" do
        expect(SimpleProviders.has_provider?(:name)).to eq true
        expect(SimpleProviders.new.has_provider?('name')).to eq false
        expect(SimpleProviders.has_provider?('instrument')).to eq true
        expect(SimpleProviders.new.has_provider?(:instrument)).to eq false
      end

      it "lets you overwrite existing simple providers" do
        SimpleProviders.provides({:name => 'Erik'})
        expect(SimpleProviders.new.take(:name)).to eq 'Erik'
      end

      it "lets you write linked notation" do
        expect(SimpleProviders.provides({:name => 'Lane'}).new.take(:name)).to eq 'Lane'
      end

      it "works with lambdas" do
        expect(SimpleProviders.provides(:name => lambda{ 'Patrick' }).new.take(:name)).to eq 'Patrick'
      end

      it "works with Procs" do
        expect(SimpleProviders.provides(:name => Proc.new{ 'St. Patrick' }).new.take(:name)).to eq 'St. Patrick'
      end
    end

    describe "#add" do
      module OddProviders
        include DataProvider::Base
        provides({1 => 'one'})
        provider :three do 3 end
      end

      module OddOverwriteProviders
        include DataProvider::Base
        provides({1 => 'Uno', :five => 555})
        provider :three do :tres end
      end

      class BasicProviders
        include DataProvider::Base
        provides({2 => '1'})
        provider :four do '4' end
        add OddProviders
      end

      it "lets you add providers from another module" do
        expect(BasicProviders.has_provider?(1)).to eq true
        expect(BasicProviders.has_provider?(2)).to eq true
        expect(BasicProviders.has_provider?(:three)).to eq true
        expect(BasicProviders.has_provider?(:four)).to eq true
        # expect(BasicProviders.new.take(1)).to eq 'one'
        expect(BasicProviders.new.take(:three)).to eq 3
      end

      it "lets you add providers from another module at runtime" do
        expect(BasicProviders.has_provider?(:five)).to eq false
        BasicProviders.add(OddOverwriteProviders)
        expect(BasicProviders.has_provider?(:five)).to eq true
      end

      # for the following test the providers of OddOverwriteProviders
      # have already been added (by the previous test)
      it "lets overwrite providers" do
        expect(BasicProviders.new.take(1)).to eq 'Uno'
        expect(BasicProviders.new.take(:three)).to eq :tres
      end

      it "includes providers which can be overwritten" do
        klass = Class.new(Object) do
          include DataProvider::Base
          add OddProviders
          provider :three do '33' end
        end

        expect(klass.new.take(:three)).to eq '33'
      end

      it "can be used in modules, latest provider always overwrites the previous" do
        m1 = Module.new do
          include DataProvider::Base

          # this provider should get overwritten by the m2 version
          provider :aa do 'aa1' end
        end

        m2 = Module.new do
          include DataProvider::Base
          add m1

          # this provider should overwrite the m1 version
          provider :aa do 'aa2' end
        end

        c = Class.new(Object) do
          include DataProvider::Base

          # this provider gets overwritten when we do the add call below
          provider :aa do 'aa3' end

          add m2
        end

        expect(c.new.take(:aa)).to eq 'aa2'
      end
    end

    describe "#add_scoped" do
      module ChildProviders
        include DataProvider::Base
        provider :name do "child" end
      end

      module GrandchildProviders
        include DataProvider::Base
        provider :name do "grandchild" end
        provider [:age] do 1 end
        provides({
          :mommy => 'Wilma',
          :daddy => 'Fret'
        })

        provider :mobility do
          'crawling'
        end

        provider :movement do
          take(:mobility)
        end

        provider :symbol do
          'Symbol provider'
        end

        provider :sym do
          take(:symbol)
        end

        provider ['string'] do
          'String provider: ' + take(:symbol)
        end
      end

      class ProviderKlass
        include DataProvider::Base
        provider :parent do 'parent' end
        add_scoped ChildProviders, :scope => :child
        add_scoped GrandchildProviders, :scope => [:child, :child]
      end

      it 'let you array-prefix the providers of an included module' do
        expect(ProviderKlass.has_provider?(:parent)).to eq true
        expect(ProviderKlass.has_provider?(:name)).to eq false
        expect(ProviderKlass.has_provider?([:child, :name])).to eq true
        expect(ProviderKlass.has_provider?([:child, :age])).to eq false
        expect(ProviderKlass.has_provider?([:child, :child, :name])).to eq true
        expect(ProviderKlass.has_provider?([:child, :child, :age])).to eq true
        expect(ProviderKlass.has_provider?([:child, :child, :mommy])).to eq true
        expect(ProviderKlass.has_provider?([:child, :child, :daddy])).to eq true
        expect(ProviderKlass.new.take([:child, :name])).to eq 'child'
        expect(ProviderKlass.new.take([:child, :child, :name])).to eq 'grandchild'
        expect(ProviderKlass.new.take([:child, :child, :age])).to eq 1
        expect(ProviderKlass.new.take([:child, :child, :mommy])).to eq 'Wilma'
        expect(ProviderKlass.new.take([:child, :child, :daddy])).to eq 'Fret'
      end

      it "#take acts like #scoped_take inside providers works for add_scoped modules as well" do
        expect( ProviderKlass.new.take([:child, :child, :mobility]) ).to eq 'crawling'
        expect( ProviderKlass.new.take([:child, :child, :movement]) ).to eq 'crawling'
      end

      it "doesn't act up when mixing symbols and strings in array identifiers" do
        expect( ProviderKlass.new.take([:child, :child, 'string']) ).to eq 'String provider: Symbol provider'
      end

      it "lets #take act like #scoped_take recursively" do
        expect( ProviderKlass.new.take([:child, :child, :sym]) ).to eq 'Symbol provider'
      end

      it 'respect provider order/priority' do
        m1 = Module.new do
          include DataProvider::Base
          provider 'version' do 1 end
        end

        m2 = Module.new do
          include DataProvider::Base
          add m1
          provider 'version' do 2 end
        end

        c = Class.new(Object) do
          include DataProvider::Base
          provider 'version' do 0 end
          provider ['module', 'version'] do -1 end
          add_scoped m2, :scope => 'module'
        end

        expect(c.new.try_take('version')).to eq 0
        expect(c.new.try_take(['module', 'version'])).to eq 2
      end

      it 'works recursively' do
        m1 = Module.new do
          include DataProvider::Base
          provider ['name'] do 'Johnny Blaze' end
        end

        expect(m1.provider_identifiers).to eq [['name']]

        m2 = Module.new do
          include DataProvider::Base
          # this next line adds the provider ['name'] to m2
          add m1
        end

        expect(m2.provider_identifiers).to eq [['name']]

        m3 = Module.new do
          include DataProvider::Base
          # this provider will end up like ['creatures', 'name'] in c1
          provider ['name'] do 'Mr. Nobody' end
          # the next line adds the provider ['person', 'name'] to m3
          add_scoped m2, :scope => 'person'
        end

        # providers are internally added in reverse order
        expect(m3.provider_identifiers).to eq [['person', 'name'], ['name']]

        c1 = Class.new(Object) do
          include DataProvider::Base
          # the next line will add the provides ['creatures', 'name'] and ['creatures', 'person', 'name']
          add_scoped m3, :scope => 'creatures'
        end

        expect(c1.has_provider?('name')).to eq false
        expect(c1.has_provider?(['name'])).to eq false
        expect(c1.has_provider?(['person', 'name'])).to eq false
        expect(c1.has_provider?(['creatures', 'person', 'name'])).to eq true
        expect(c1.new.take(['creatures', 'person', 'name'])).to eq 'Johnny Blaze'
      end

      it "doesn't affect the added module" do
        m1 = Module.new do
          include DataProvider::Base
          provider ['name'] do 'Johnny Blaze' end
        end

        expect(m1.provider_identifiers).to eq [['name']]

        c1 = Class.new(Object) do
          include DataProvider::Base
          add_scoped m1, :scope => 'prefix'
        end

        expect(m1.provider_identifiers).to eq [['name']]
      end
    end

    describe "provider_missing" do
      it "lets you define a default fallback provider" do
        klass = Class.new Object do
          include DataProvider::Base
          provider_missing do
            "This provider don't exist!"
          end
        end

        expect(klass.has_provider?(:message)).to eq false
        expect(klass.new.take(:message)).to eq "This provider don't exist!"
      end

      it "provides the missing provider id through the private missing_provider method" do
        klass = Class.new Object do
          include DataProvider::Base
          provider_missing do
            "Missing #{missing_provider}"
          end
        end

        expect(klass.new.take(:something)).to eq 'Missing something'
        expect{klass.new.missing_provider}.to raise_error(NoMethodError)
      end

      it 'calls the fallback provider when using try_take with an unknown provider' do
        klass = Class.new Object do
          include DataProvider::Base
          provider_missing do
            "fallback_#{missing_provider}"
          end
        end

        expect(klass.new.try_take(:cool)).to eq 'fallback_cool'
      end     
    end

    describe "fallback_provider?" do
      it "lets you know if a fallback provider has been registered" do
        klass = Class.new Object do
          include DataProvider::Base
        end

        expect(klass.fallback_provider?).to eq false

        klass.provider_missing do
          "New fallback!"
        end

        expect(klass.fallback_provider?).to eq true
      end
    end
  end

  describe "Instance level" do
    describe "#has_provider?" do
      it 'tells if the instance knows the specified provider' do
        expect(provider.has_provider?(:sum)).to be true
        expect(provider.has_provider?(:static)).to be true
        expect(provider.has_provider?(:modulus)).to be false
      end
    end

    describe "#has_providers_with_scope?" do
      let(:klass){
        Class.new Object do
          include DataProvider::Base
          provider [:a, :b ,:c]
          provider :unscoped
        end
      }

      it "return true if there are providers defined with an array identifier that start with the given prefix" do
        expect(klass.new.has_providers_with_scope?(:unscoped)).to eq false
        expect(klass.new.has_providers_with_scope?(:a)).to eq true
        expect(klass.new.has_providers_with_scope?([:a, :b])).to eq true
        # scope means prefix, identfier may not be exactly the given array
        expect(klass.new.has_providers_with_scope?([:a, :b, :c])).to eq false
      end
    end

    describe "#take" do
      it 'lets you take data from a data provider instance' do
        expect(provider.take(:sum)).to eq 7
        expect(provider.take(:static)).to eq 'StaticValue'
      end

      it 'raise a ProviderMissingException when attempting to take from unknown provider' do
        expect{provider.take(:unknown)}.to raise_error(DataProvider::ProviderMissingException)
        expect{provider.take([:identification, :foo])}.to raise_error(DataProvider::ProviderMissingException)
      end

      it 'works from within a provider block' do
        expect(provider.take(:billy)).to eq 'Billy Bragg'
      end

      it "acts like #scoped_take when used inside a provider and the specified provider isn't available" do
        expect(provider.take([:identification, :id])).to eq 'Stephen William Bragg'
        expect(provider.take([:identification, :identifier])).to eq 'Billy'
      end

      it "can act like #scoped_take recursively" do
        expect(provider.take([:identification, :ID])).to eq 'Stephen William Bragg'
      end
    end

    describe "#try_take" do
      it "acts like #take when the specified provider is present" do
        expect(provider.try_take(:sum)).to eq 7
      end

      it "returns nil when the specified provider is not found" do
        expect(provider.try_take(:square_root)).to eq nil
      end
    end

    describe "#scope" do
      let(:klass){
        Class.new Object do
          include DataProvider::Base
          provider [:a, :b] do
            'woeha!'
          end
          provider [:a, :b ,:c] do
            scope
          end

          provider [:a, :b ,:eq] do
            take scope
          end
        end
      }

      it 'gives providers the current scope' do
        expect(klass.new.take([:a,:b,:c])).to eq [:a,:b]
      end

      it "can be used by providers to call the 'parent provider'" do
        expect(klass.new.take([:a,:b,:eq])).to eq klass.new.take([:a,:b])
      end
    end

    describe "#scoped_take" do
      it 'lets a provider call providers within its own scope' do
        expect(provider.take([:identification, :fullname])).to eq 'Billy Bragg'
      end
      # it 'lets attribute providers'
    end

    describe "#give" do
      it "lets you give data, creating a new data provider instance" do
        updated_provider = provider.give :array => [1,80]
        expect(provider.take(:sum)).to eq 7
        expect(updated_provider.take(:sum)).to eq 81
      end

      it "allows for linked notation" do
        expect(provider.give(:array => [7, -3]).take(:sum)).to eq 4
      end

      it "has an add_scope alias" do
        expect(provider.add_scope(:array => [400, 20]).take(:sum)).to eq 420
      end

      it "has an add_data alias" do
        expect(provider.add_data(:array => [400, 20]).take(:sum)).to eq 420
      end
    end

    describe "#give!" do
      it "lets you update the current provider with additional data" do
        prov = ProviderClass.new(:data => {:array => [1,1,90]})
        expect(prov.take(:sum)).to eq 92
        prov.give!(:array => [3,90])
        expect(prov.take(:sum)).to eq 93
      end

      it "allows for linked notation" do
        expect(provider.give.give!(:array => [-1, -4]).take(:sum)).to eq -5
      end

      it "has an add_scope! alias" do
        newprovider = provider.add_scope
        newprovider.add_scope!(:array => [-1, -4])
        expect(newprovider.given(:array)).to eq [-1,-4]
        expect(newprovider.take(:sum)).to eq -5
      end

      it "has an add_data! alias" do
        scoped_provider = provider.add_data(:array => []).add_data!(:array => [5, 5])
        expect(scoped_provider.get_data(:array)).to eq [5,5]
        expect(scoped_provider.take(:sum)).to eq 10
      end
    end

    describe '#got?' do
      it "returns if the specified piece of data is given" do
        obj = ProviderClass.new(:data => {:name => 'John'})
        expect( obj.got?(:lastname) ).to be false
        expect( obj.got?(:name) ).to be true
        expect( obj.give(:lastname => 'Doe').got?(:lastname) ).to be true
      end

      it "has an 'has_data?' alias" do
        obj = ProviderClass.new(:data => {:name => 'John'})
        expect( obj.has_data?(:lastname) ).to be false
        expect( obj.has_data?(:name) ).to be true
        expect( obj.add_data(:lastname => 'Doe').has_data?(:lastname) ).to be true
      end
    end

    describe "#given" do 
      it "has a given method to get given data" do
        expect(provider.given(:array)).to eq [1,2,4]
        expect(provider.give(:array => 'array').given(:array)).to eq 'array'
      end

      it "has a get_data alias" do
        expect(provider.get_data(:array)).to eq provider.given(:array)
      end
    end

    describe "fallback_provider?" do
      it "lets you know if a fallback provider has been registered" do
        klass = Class.new Object do
          include DataProvider::Base
        end

        expect(klass.new.fallback_provider?).to eq false

        klass.provider_missing do
          "New fallback!"
        end

        expect(klass.new.fallback_provider?).to eq true
      end
    end

    describe "#add!" do
      let(:m){
        Module.new do
          include DataProvider::Base
          provider :new_provider do
            "I'm new!"
          end
        end
      }

      let(:klass){
        Class.new(Object) do include DataProvider::Base end
      }

      let(:instance){
        klass.new
      }

      it "adds data providers from a module to itself" do
        # before
        expect(instance.has_provider?(:new_provider)).to eq false
        expect(instance.try_take(:new_provider)).to eq nil

        # add!
        instance.add!(m)

        # after
        expect(instance.has_provider?(:new_provider)).to eq true
        expect(instance.try_take(:new_provider)).to eq "I'm new!"
      end

      it "returns self" do
        expect(instance.add!(m)).to be instance
      end
    end

    describe "#add" do
      it "adds modules to a clone and returns that clone" do
        m = Module.new do
          include DataProvider::Base
          provider :new_provider do
            "I'm new!"
          end
        end

        klass = Class.new(Object) do include DataProvider::Base end
        instance = klass.new

        # before
        expect(instance.has_provider?(:new_provider)).to eq false
        expect(instance.try_take(:new_provider)).to eq nil

        # add
        clone = instance.add(m)

        # after
        expect(instance.has_provider?(:new_provider)).to eq false
        expect(instance.try_take(:new_provider)).to eq nil

        expect(clone.has_provider?(:new_provider)).to eq true
        expect(clone.try_take(:new_provider)).to eq "I'm new!"
      end
    end
  end
end