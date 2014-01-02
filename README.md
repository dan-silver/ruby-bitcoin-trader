ruby-bitcoin-trader
===================

Automatically trades bitcoins using the coinbase api

### Setup

After creating a Coinbase account, manually purchase the initial amount of Bitcoins to be traded.  Then, use their web interface to get your API key and save it locally as the `COINBASE_API_KEY` environmental variable.

### Trading
#### Basic Example
```ruby
#Start automatic trading
load 'trader.rb'
trader = Trader.new
trader.trade

```
#### Synchronize local database and Coinbase history
```ruby
#Run this code if you manually make a trade through the Coinbase website to update your local database
trader = Trader.new
trader.pull_transactions_from_coinbase
```
