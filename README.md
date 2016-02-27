# data-provider
Ruby gem that provides a set of classes to build consistent data interfaces

[![Build Status](https://travis-ci.org/markkorput/data-provider.svg)](https://travis-ci.org/markkorput/data-provider)
[![Code Health](https://codeclimate.com/github/markkorput/data-provider/badges/gpa.svg)](https://codeclimate.com/github/markkorput/data-provider) 

## Installation

Rubygems:
```
gem install data-provider
```

Bundler:
```ruby
gem 'data-provider'
```

## Examples

Define a provider class with some providers
```ruby

require 'data_provider'

class BookProvider
	include DataProvider::Base
	
	# quick syntax for 'simple' providers
	provides({
		title: 'The Monkey Wrench Gang',
		author: 'Edward Abbey'
	})
	
	# longer syntax for more complicated providers
	provider :display_title do
		"#{take(:author)} - #{take(:title)}"
	end

	provider :price do
		9.99
	end
end
```

Using a provider class
```ruby
book_provider = BookProvider.new()
book_provider.take(:title) # => 'The Monkey Wrench Gang'
book_provider.take(:author) # => 'Edward Abbey'
book_provider.take(:display_title) # => 'Edward Abbey - The Monkey Wrench Gang'
book_provider.take(:price) # => 9.99
```

Data providers can be given data to customize their output
```ruby
require 'data_provider'

class ProductProvider
	include DataProvider::Base
	
	provider :normal_price do
		17.99
	end
	
	provider :discount_price do
		take(:normal_price) - get_data(:discount)
	end
end

product_provider = ProductProvider.new
product_provider.take(:normal_price) # => 17.99
product_provider.take(:discount_price) # => TypeError (discount data not given,): nil can't be coerced into Float
discounted_provider = product_provider.add_data(discount: 3.0) # returns a new instance of the same provider class
discounted_provider.take(:discount_price) # => 14.99
product_provider.take(:discount_price) # => TypeError (this instance didn't get the new data)
product_provider.add_data!(discount: 2) # => Updates this instance instead of creating a new one
product_provider.take(:discount_price) # => 15.99
product_provider.add_data!(discount: 4).take(:discount_price) #=> 13.99
```

Providers can be defined in a module and added to a provider class using the add class-method (not using include!)
```ruby
require 'data-provider'

module BandInfo
	include DataProvider::Base
	
	provider :band do
		'D4'
	end
	
	provider :bassPlayer do
		'Paddy'
	end
end

class Band
	include DataProvider::Base
	
	provider :band do
		'Dillinger Four'
	end
	
	provider :drummer do
		'Lane Pederson'
	end

	add BandInfo # note: add, not include!
end

band = Band.new
band.take(:band) # => 'D4', class provider was overwritten when the module got added
band.take(:bassPlayer) # => 'Paddy'
band.take(:drummer) #=> 'Lane Pederson'
```

Provider identifiers don't have to be symbols, they can be anything. Specifically array identifiers are suitable for creating data providers for hierarchical systems
```ruby
require 'data_provider'

module AlbumProvider
	include DataProvider::Base
	
	provides({
		title: 'Reinventing Axle Rose',
		band: 'Against Me!'
		[:band, :hometown] => 'Gainesville, FL'
	})
end

class Catalog
	include DataProvider::Base
	
	provider [:music, :album, :bandname] do
		# scoped_take is a method only available inside provider blocks,
		# it lets a provider access other providers in the same 'scope',
		# which means provider whose array-identifiers start with the same values,
		# in this case the scope is [:music, :album]
		scoped_take(:band).upcase
	end

	# by using `add_scoped` all providers of the added module, will be
	# turned into array and prefixed with the given scope
	add_scoped AlbumProvider, :scope => [:music, :album]
end

catalog = Catalog.new
catalog.take(:title) # => DataProvider::ProviderMissingException
catalog.take([:music, :album, :title]) # => 'Reinventing Axle Rose'
catalog.take([:music, :album, :band, :hometown]) # => 'Gainesville, FL'
catalog.take([:music, :album, :bandname]) # => 'AGAINST ME!"
```
