# data-provider
Ruby gem that provides a set of classes to build consistent data interfaces

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
		:title => 'The Monkey Wrench Gang',
		:author => 'Edward Abbey'
	})
	
	# longer syntax for more complicated providers
	provider :display_title do
		"#{take(:author) - #{take(:title)}"
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