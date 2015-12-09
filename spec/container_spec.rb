require File.dirname(__FILE__) + '/spec_helper'

describe DataProvider::Container do
    # Example implementation of DataProvider::Base
  let(:container){
    DataProvider::Container.new.tap do |container|
      container.provider :sum, :requires => [:array] do
        sum = 0

        (given(:array) || []).each do |number|
          sum += number.to_i
        end

        sum
      end

      container.provider :static do
        'StaticValue'
      end

      container.provider :billy do
        take([:identification, :fullname])
      end

      container.provider [:identification, :firstname] do
        'Billy'
      end

      container.provider [:identification, :lastname] do
        'Bragg'
      end

      container.provider [:identification, :fullname] do
        "#{scoped_take(:firstname)} #{scoped_take(:lastname)}"
      end

      container.provider [:identification, :identifier] do
        take(:firstname)
      end

      container.provider :fullname do
        'Stephen William Bragg'
      end

      container.provider [:identification, :id] do
        take(:fullname)
      end

      container.provider [:identification, :ID] do
        take(:id)
      end
    end
  }

  describe "#has_provider?" do
    it 'tells if the specified provider exists' do
      expect(container.respond_to?(:has_provider?)).to eq true
      expect(container.has_provider?(:sum)).to eq true
      expect(container.has_provider?(:divid)).to eq false
    end
  end

  describe "#has_providers_with_scope?" do
    let(:container){
      DataProvider::Container.new.tap do |container|
        container.provider [:a, :b ,:c]
        container.provider :unscoped
      end
    }

    it "return true if there are providers defined with an array identifier that start with the given prefix" do
      expect(container.has_providers_with_scope?(:unscoped)).to eq false
      expect(container.has_providers_with_scope?(:a)).to eq true
      expect(container.has_providers_with_scope?([:a, :b])).to eq true
      # scope means prefix, identfier may not be exactly the given array
      expect(container.has_providers_with_scope?([:a, :b, :c])).to eq false
    end
  end

  describe "#provides" do
    let(:container){
      DataProvider::Container.new.tap do |container|
        container.provides({
          :name => 'Paddy',
          'instrument' => :bass
        })
      end
    }
    # class SimpleProviders
    #   include DataProvider::Base
    #   provides({
    #     :name => 'Paddy',
    #     'instrument' => :bass,
    #   })
    # end

    it "lets you request all currently available simple providers when called without a parameter" do
      expect(container.provides).to eq({
        :name => 'Paddy',
        'instrument' => :bass
      })
    end

    it "lets you define simple providers" do
      expect(container.take(:name)).to eq 'Paddy'
      expect(container.take('instrument')).to eq :bass
    end

    it "works with has_provider?" do
      expect(container.has_provider?(:name)).to eq true
      expect(container.has_provider?('name')).to eq false
      expect(container.has_provider?('instrument')).to eq true
      expect(container.has_provider?(:instrument)).to eq false
    end

    it "lets you overwrite existing simple providers" do
      container.provides({:name => 'Erik'})
      expect(container.take(:name)).to eq 'Erik'
    end

    it "lets you write linked notation" do
      expect(container.provides({:name => 'Lane'}).take(:name)).to eq 'Lane'
    end

    it "works with lambdas" do
      expect(container.provides(:name => lambda{ 'Patrick' }).take(:name)).to eq 'Patrick'
    end

    it "works with Procs" do
      expect(container.provides(:name => Proc.new{ 'St. Patrick' }).take(:name)).to eq 'St. Patrick'
    end
  end

  describe "#add!" do
    let(:odd_providers){
      DataProvider::Container.new.tap do |c|
        c.provides({1 => 'one'})
        c.provider :three do 3 end
      end
    }

    let(:odd_overwrite_providers){
      DataProvider::Container.new.tap do |c|
        c.provides({1 => 'Uno', :five => 555})
        c.provider :three do :tres end
      end
    }

    let(:container){
      DataProvider::Container.new.tap do |container|
        container.provides({2 => '1'})
        container.provider :four do '4' end
        container.add! odd_providers
      end
    }

    it "lets you add providers from another container" do
      expect(container.has_provider?(1)).to eq true
      expect(container.has_provider?(2)).to eq true
      expect(container.has_provider?(:three)).to eq true
      expect(container.has_provider?(:four)).to eq true
      # expect(BasicProviders.new.take(1)).to eq 'one'
      expect(container.take(:three)).to eq 3
    end

    it "lets you add providers from another container at runtime" do
      expect(container.has_provider?(:five)).to eq false
      container.add!(odd_overwrite_providers)
      expect(container.has_provider?(:five)).to eq true
    end

    # for the following test the providers of OddOverwriteProviders
    # have already been added (by the previous test)
    it "lets you overwrite providers" do
      container.add!(odd_overwrite_providers)
      expect(container.take(1)).to eq 'Uno'
      expect(container.take(:three)).to eq :tres
    end

    it "includes providers which can be overwritten" do
      cont = DataProvider::Container.new
      cont.add! odd_providers
      cont.provider :three do '33' end
      expect(cont.take(:three)).to eq '33'
    end
  end

  describe "#add" do
    let(:odd_providers){
      DataProvider::Container.new.tap do |c|
        c.provides({1 => 'one'})
        c.provider :three do 3 end
      end
    }

    let(:odd_overwrite_providers){
      DataProvider::Container.new.tap do |c|
        c.provides({1 => 'Uno', :five => 555})
        c.provider :three do :tres end
      end
    }

    let(:container){
      DataProvider::Container.new.tap do |container|
        container.provides({2 => '1'})
        container.provider :four do '4' end
        container.add odd_providers
      end
    }

    it "lets you add providers from another container" do
      expect(container.has_provider?(1)).to eq false
      expect(container.has_provider?(2)).to eq true
      expect(container.has_provider?(:three)).to eq false
      expect(container.has_provider?(:four)).to eq true
      # expect(BasicProviders.new.take(1)).to eq 'one'
      # expect(container.take(:three)).to eq 3
    end

    it "lets you add providers from another container at runtime" do
      expect(container.has_provider?(:five)).to eq false
      new_container = container.add(odd_overwrite_providers)
      expect(container.has_provider?(:five)).to eq false
      expect(new_container.has_provider?(:five)).to eq true
    end

    # for the following test the providers of OddOverwriteProviders
    # have already been added (by the previous test)
    it "lets you overwrite providers" do
      new_container = container.add(odd_overwrite_providers)
      expect(container.has_provider?(1)).to eq false
      expect(new_container.take(1)).to eq 'Uno'
      expect(container.has_provider?(:three)).to eq false
      expect(new_container.take(:three)).to eq :tres
    end

    it "includes providers which can be overwritten" do
      cont = DataProvider::Container.new
      odd = cont.add odd_providers
      odd.provider :three do '33' end
      expect(odd.take(:three)).to eq '33'
    end
  end

  describe "#add_scoped!" do
    let(:child_providers){
      DataProvider::Container.new.tap do |c|
        c.provider :name do "child" end
      end
    }

    let(:grandchild_providers){
      DataProvider::Container.new.tap do |c|
        c.provider :name do "grandchild" end
        c.provider [:age] do 1 end
        c.provides({
          :mommy => 'Wilma',
          :daddy => 'Fret'
        })

        c.provider :mobility do
          'crawling'
        end

        c.provider :movement do
          take(:mobility)
        end

        c.provider :symbol do
          'Symbol provider'
        end

        c.provider :sym do
          take(:symbol)
        end

        c.provider ['string'] do
          'String provider: ' + take(:symbol)
        end
      end
    }

    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider :parent do 'parent' end
        c.add_scoped! child_providers, :scope => :child
        c.add_scoped! grandchild_providers, :scope => [:child, :child]
      end
    }

    it 'let you array-prefix the providers of an included container' do
      expect(container.has_provider?(:parent)).to eq true
      expect(container.has_provider?(:name)).to eq false
      expect(container.has_provider?([:child, :name])).to eq true
      expect(container.has_provider?([:child, :age])).to eq false
      expect(container.has_provider?([:child, :child, :name])).to eq true
      expect(container.has_provider?([:child, :child, :age])).to eq true
      expect(container.has_provider?([:child, :child, :mommy])).to eq true
      expect(container.has_provider?([:child, :child, :daddy])).to eq true
      expect(container.take([:child, :name])).to eq 'child'
      expect(container.take([:child, :child, :name])).to eq 'grandchild'
      expect(container.take([:child, :child, :age])).to eq 1
      expect(container.take([:child, :child, :mommy])).to eq 'Wilma'
      expect(container.take([:child, :child, :daddy])).to eq 'Fret'
    end

    it "#take acts like #scoped_take inside providers works for add_scoped containers as well" do
      expect( container.take([:child, :child, :mobility]) ).to eq 'crawling'
      expect( container.take([:child, :child, :movement]) ).to eq 'crawling'
    end

    it "doesn't act up when mixing symbols and strings in array identifiers" do
      expect( container.take([:child, :child, 'string']) ).to eq 'String provider: Symbol provider'
    end

    it "lets #take act like #scoped_take recursively" do
      expect( container.take([:child, :child, :sym]) ).to eq 'Symbol provider'
    end

    it 'respect provider order/priority' do
      c1 = DataProvider::Container.new
      c1.provider 'version' do 1 end

      c2 = DataProvider::Container.new
      c2.add! c1
      c2.provider 'version' do 2 end

      c = DataProvider::Container.new
      c.provider 'version' do 0 end
      c.provider ['module', 'version'] do -1 end
      c.add_scoped! c2, :scope => 'module'

      expect(c.try_take('version')).to eq 0
      expect(c.try_take(['module', 'version'])).to eq 2
    end

    it 'works recursively' do
      c1 = DataProvider::Container.new
      c1.provider ['name'] do 'Johnny Blaze' end

      expect(c1.provider_identifiers).to eq [['name']]

      c2 = DataProvider::Container.new.add(c1)
      expect(c2.provider_identifiers).to eq [['name']]

      c3 = DataProvider::Container.new
      c3.provider ['name'] do 'Mr. Nobody' end
      # the next line adds the provider ['person', 'name'] to m3
      c3.add_scoped! c2, :scope => 'person'

      # providers are internally added in reverse order
      expect(c3.provider_identifiers).to eq [['person', 'name'], ['name']]

      c = DataProvider::Container.new
      c.add_scoped! c3, :scope => 'creatures'

      expect(c.has_provider?('name')).to eq false
      expect(c.has_provider?(['name'])).to eq false
      expect(c.has_provider?(['person', 'name'])).to eq false
      expect(c.has_provider?(['creatures', 'person', 'name'])).to eq true
      expect(c.take(['creatures', 'person', 'name'])).to eq 'Johnny Blaze'
    end

    it "doesn't affect the added container" do
      c1 = DataProvider::Container.new
      c1.provider ['name'] do 'Johnny Blaze' end

      expect(c1.provider_identifiers).to eq [['name']]

      c = DataProvider::Container.new
      c.add_scoped! c1, :scope => 'prefix'

      expect(c1.provider_identifiers).to eq [['name']]
    end
  end

  describe "#add_scoped" do
    let(:child_providers){
      DataProvider::Container.new.tap do |c|
        c.provider :name do "child" end
      end
    }

    let(:grandchild_providers){
      DataProvider::Container.new.tap do |c|
        c.provider :name do "grandchild" end
        c.provider [:age] do 1 end
        c.provides({
          :mommy => 'Wilma',
          :daddy => 'Fret'
        })

        c.provider :mobility do
          'crawling'
        end

        c.provider :movement do
          take(:mobility)
        end

        c.provider :symbol do
          'Symbol provider'
        end

        c.provider :sym do
          take(:symbol)
        end

        c.provider ['string'] do
          'String provider: ' + take(:symbol)
        end
      end
    }

    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider :parent do 'parent' end
        c.add_scoped child_providers, :scope => :child
        c.add_scoped grandchild_providers, :scope => [:child, :child]
      end
    }

    it 'let you array-prefix the providers of an included container' do
      expect(container.has_provider?(:parent)).to eq true
      expect(container.has_provider?(:name)).to eq false
      expect(container.has_provider?([:child, :name])).to eq false
      expect(container.has_provider?([:child, :age])).to eq false
      expect(container.has_provider?([:child, :child, :name])).to eq false
      expect(container.has_provider?([:child, :child, :age])).to eq false
      expect(container.has_provider?([:child, :child, :mommy])).to eq false
      expect(container.has_provider?([:child, :child, :daddy])).to eq false
      # expect(container.take([:child, :name])).to eq 'child'
      # expect(container.take([:child, :child, :name])).to eq 'grandchild'
      # expect(container.take([:child, :child, :age])).to eq 1
      # expect(container.take([:child, :child, :mommy])).to eq 'Wilma'
      # expect(container.take([:child, :child, :daddy])).to eq 'Fret'
    end

    it "#take acts like #scoped_take inside providers works for add_scoped containers as well" do
      newcontainer = container.add_scoped(child_providers, :scope => :child).add_scoped(grandchild_providers, :scope => [:child, :child])
      expect( newcontainer.take([:child, :child, :mobility]) ).to eq 'crawling'
      expect( newcontainer.take([:child, :child, :movement]) ).to eq 'crawling'
    end

    it "doesn't act up when mixing symbols and strings in array identifiers" do
      newcontainer = container.add_scoped(child_providers, :scope => :child).add_scoped(grandchild_providers, :scope => [:child, :child])
      expect( newcontainer.take([:child, :child, 'string']) ).to eq 'String provider: Symbol provider'
    end

    it "lets #take act like #scoped_take recursively" do
      newcontainer = container.add_scoped(child_providers, :scope => :child).add_scoped(grandchild_providers, :scope => [:child, :child])
      expect( newcontainer.take([:child, :child, :sym]) ).to eq 'Symbol provider'
    end

    it 'respect provider order/priority' do
      c1 = DataProvider::Container.new
      c1.provider 'version' do 1 end

      c2 = DataProvider::Container.new
      c2.add c1
      c2.provider 'version' do 2 end

      c = DataProvider::Container.new
      c.provider 'version' do 0 end
      c.provider ['module', 'version'] do -1 end
      cc = c.add_scoped c2, :scope => 'module'

      expect(cc.try_take('version')).to eq 0
      expect(cc.try_take(['module', 'version'])).to eq 2
    end

    it 'works recursively' do
      c1 = DataProvider::Container.new
      c1.provider ['name'] do 'Johnny Blaze' end

      expect(c1.provider_identifiers).to eq [['name']]

      c2 = DataProvider::Container.new.add(c1)
      expect(c2.provider_identifiers).to eq [['name']]

      c3 = DataProvider::Container.new
      c3.provider ['name'] do 'Mr. Nobody' end
      # the next line adds the provider ['person', 'name'] to m3
      c4 = c3.add_scoped c2, :scope => 'person'

      # providers are internally added in reverse order
      expect(c4.provider_identifiers).to eq [['person', 'name'], ['name']]

      c = DataProvider::Container.new
      cc = c.add_scoped c3, :scope => 'creatures'

      expect(cc.has_provider?('name')).to eq false
      expect(cc.has_provider?(['name'])).to eq false
      expect(cc.has_provider?(['person', 'name'])).to eq false
      expect(cc.has_provider?(['creatures', 'person', 'name'])).to eq false
      ccc = cc.add_scoped c4, :scope => 'creatures'
      expect(ccc.has_provider?(['creatures', 'person', 'name'])).to eq true
      expect(ccc.take(['creatures', 'person', 'name'])).to eq 'Johnny Blaze'
    end

    it "doesn't affect the added container" do
      c1 = DataProvider::Container.new
      c1.provider ['name'] do 'Johnny Blaze' end

      expect(c1.provider_identifiers).to eq [['name']]

      c = DataProvider::Container.new
      c2 = c.add_scoped c1, :scope => 'prefix'

      expect(c1.provider_identifiers).to eq [['name']]
    end
  end

  describe "#provider_missing" do
    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider_missing do
          "This provider don't exist!"
        end
      end
    }

    it "lets you define a default fallback provider" do
      expect(container.has_provider?(:message)).to eq false
      expect(container.take(:message)).to eq "This provider don't exist!"
    end

    describe "#missing_provider" do
      it "provides the missing provider id through the missing_provider method" do
        c = DataProvider::Container.new
        c.provider_missing do
          "Missing #{missing_provider}"
        end

        expect(c.take(:something)).to eq 'Missing something'
      end

      it "returns nil when called from anywhere else than the fallback provider" do
        # expect{c.missing_provider}.to raise_error(NoMethodError)
        expect(container.missing_provider).to eq nil
      end
    end

    it 'calls the fallback provider when using try_take with an unknown provider' do
      c = DataProvider::Container.new
      c.provider_missing do
        "fallback_#{missing_provider}"
      end

      expect(c.try_take(:cool)).to eq 'fallback_cool'
    end     
  end

  describe "fallback_provider?" do
    it "lets you know if a fallback provider has been registered" do
      c = DataProvider::Container.new
      expect(c.fallback_provider?).to eq false

      c.provider_missing do
        "New fallback!"
      end

      expect(c.fallback_provider?).to eq true
    end
  end

  describe "#take" do
    it 'lets you take data from a data provider instance' do
      expect(container.give(:array => [6,9,2]).take(:sum)).to eq 17
      expect(container.take(:static)).to eq 'StaticValue'
    end

    it 'raise a ProviderMissingException when attempting to take from unknown provider' do
      expect{container.take(:unknown)}.to raise_error(DataProvider::ProviderMissingException)
      expect{container.take([:identification, :foo])}.to raise_error(DataProvider::ProviderMissingException)
    end

    it 'works from within a provider block' do
      expect(container.take(:billy)).to eq 'Billy Bragg'
    end

    it "acts like #scoped_take when used inside a provider and the specified provider isn't available" do
      expect(container.take([:identification, :id])).to eq 'Stephen William Bragg'
      expect(container.take([:identification, :identifier])).to eq 'Billy'
    end

    it "can act like #scoped_take recursively" do
      expect(container.take([:identification, :ID])).to eq 'Stephen William Bragg'
    end
  end

  describe "#try_take" do
    it "acts like #take when the specified provider is present" do
      expect(container.give(:array => [1,2,4]).try_take(:sum)).to eq 7
    end

    it "returns nil when the specified provider is not found" do
      expect(container.try_take(:square_root)).to eq nil
    end
  end

  describe "#provider_stack" do
    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider :a do
          take(:b)
        end
        c.provider :b do
          take(['prefix', :c])
        end
        c.provider ['prefix', :c] do
          take ['prefix', :d]
        end
        c.provider ['prefix', :d] do
          provider_stack
        end
      end
    }

    it "gives Provider objects" do
      expect(container.take(:a).map(&:class)).to eq [DataProvider::Provider]*4
    end

    it "gives providers an array resembling the current provider 'callstack'" do
      expect(container.take(:a).map(&:id)).to eq [:a, :b, ['prefix', :c], ['prefix', :d]]
      expect(container.take(:b).map(&:id)).to eq [:b, ['prefix', :c], ['prefix', :d]]
    end
  end

  describe "#provider_id" do
    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider :a do
          take(:b)
        end
        c.provider :b do
          take(['prefix', :c])
        end
        c.provider ['prefix', :c] do
          take ['prefix', :d]
        end
        c.provider ['prefix', :d] do
          provider_id
        end
      end
    }

    it "gives the id of the current provider" do
      expect(container.take(:a)).to eq ['prefix', :d]
      expect(container.take(['prefix', :d])).to eq ['prefix', :d]
    end

    it "gives nil when called from outside a provider" do
      expect(container.provider_id).to eq nil
    end
  end


  describe "#scopes" do
    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider :a do
          take(:b)
        end
        c.provider :b do
          take(['prefix', :c])
        end
        c.provider ['prefix', :c] do
          take :d # take also looks for :d within its own ['prefix'] scope
        end
        c.provider ['prefix', :d] do
          scopes
        end
      end
    }

    it "gives providers an array resembling the current provider 'callstack'" do
      expect(container.take(:a)).to eq [[], [], ['prefix'], ['prefix']]
      expect(container.take(:b)).to eq [[], ['prefix'], ['prefix']]
    end
  end

  describe "#scope" do
    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider [:a, :b] do
          'woeha!'
        end
        c.provider [:a, :b ,:c] do
          scope
        end
        c.provider [:a, :b ,:eq] do
          take scope
        end
      end
    }

    it 'gives providers the current scope' do
      expect(container.take([:a,:b,:c])).to eq [:a,:b]
    end

    it "can be used by providers to call the 'parent provider'" do
      expect(container.take([:a,:b,:eq])).to eq container.take([:a,:b])
    end
  end

  describe "#scoped_take" do
    it 'lets a provider call providers within its own scope' do
      expect(container.take([:identification, :fullname])).to eq 'Billy Bragg'
    end
  end

  describe "#give" do
    it "lets you give data, creating a new data provider instance" do
      updated = container.give :array => [1,80]
      expect(container.take(:sum)).to eq 0
      expect(updated.take(:sum)).to eq 81
    end

    it "allows for linked notation" do
      expect(container.give(:array => [7, -3]).take(:sum)).to eq 4
    end

    it "has an add_scope alias" do
      expect(container.add_scope(:array => [400, 20]).take(:sum)).to eq 420
    end

    it "has an add_data alias" do
      expect(container.add_data(:array => [400, 20]).take(:sum)).to eq 420
    end
  end

  describe "#give!" do
    it "lets you update the current provider with additional data" do
      container2 = container.give(:array => [1,1,90])
      expect(container2.take(:sum)).to eq 92
      container2.give!(:array => [3,90])
      expect(container2.take(:sum)).to eq 93
    end

    it "allows for linked notation" do
      expect(container.give!(:array => [3]).give!.give!(:array => [-1, -4]).take(:sum)).to eq -5
    end

    it "has an add_scope! alias" do
      scoped = container.add_scope.add_scope!(:array => [-1, -4])
      expect(scoped.given(:array)).to eq [-1,-4]
      expect(scoped.take(:sum)).to eq -5
    end

    it "has an add_data! alias" do
      scoped = container.add_data(:array => []).add_data!(:array => [5, 5])
      expect(scoped.get_data(:array)).to eq [5,5]
      expect(scoped.take(:sum)).to eq 10
    end
  end

  describe '#got?' do
    it "returns if the specified piece of data is given" do
      c = DataProvider::Container.new.give(:name => 'John')
      expect( c.got?(:name) ).to be true
      expect( c.got?(:lastname) ).to be false
      expect( c.give(:lastname => 'Doe').got?(:lastname) ).to be true
    end

    it "has an 'has_data?' alias" do
      c = DataProvider::Container.new.give(:name => 'John')
      expect( c.has_data?(:lastname) ).to be false
      expect( c.has_data?(:name) ).to be true
      expect( c.add_data(:lastname => 'Doe').has_data?(:lastname) ).to be true
    end
  end

  describe "#given" do 
    it "has a given method to get given data" do
      expect(DataProvider::Container.new.give(:array => 'array').given(:array)).to eq 'array'
    end

    it "has a get_data alias" do
      expect(DataProvider::Container.new.add_data(:foo => :bar).get_data(:foo)).to eq :bar
    end
  end

  describe "fallback_provider?" do
    it "lets you know if a fallback provider has been registered" do
      c = DataProvider::Container.new
      expect(c.fallback_provider?).to eq false

      c.provider_missing do
        "New fallback!"
      end

      expect(c.fallback_provider?).to eq true
    end
  end

  describe "#take_super" do
    let(:container){
      DataProvider::Container.new.tap do |c|
        c.provider :value do
          "original"
        end
      end
    }

    let(:extension1){
      DataProvider::Container.new.tap do |c|
        c.provider :value do
          "new"
        end
      end
    }

    let(:extension2){
      DataProvider::Container.new.tap do |c|
        c.provider :value do
          "#{take_super} [extended]"
        end
      end
    }

    it "gives the result of the provider with the same identifier that was added before it" do
      c = container.add extension2
      expect(c.take(:value)).to eq 'original [extended]'
      c.add! extension1
      expect(c.take(:value)).to eq 'new'
      c.add! extension2
      expect(c.take(:value)).to eq 'new [extended]'
      c.add! extension2
      expect(c.take(:value)).to eq 'new [extended] [extended]'
    end

    it "raises the ProviderMissingException if there is no older provider with the same ID" do
      instance = DataProvider::Container.new.tap do |c|
        c.provider :whatever do
          take_super
        end
      end

      expect{instance.take(:whatever)}.to raise_error(DataProvider::ProviderMissingException)
    end

  end
end