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
trader = Trader.new :percent_gain_for_sale => 0.015, :percent_drop_for_purchase => 0.02, :force_purchase_drop_percent => 0.03
trader.trade
```

#### Explanation of the parameters

`percent_gain_for_sale` Including Coinbase fees on both sides of the transaction, the percent profit that should be gained before the program sells the current amount of bitcoins in the wallet.

`percent_drop_for_purchase` What percent should the price of the bitcoin fall before buying (buy cheap, sell high).  This is calculated on a rolling average in case the bitcoin keeps rising in the current trading session.

`force_purchase_drop_percent` Since the last sale, what absolute percent should the price fall before purchasing.  This is not calculated with a rolling average.

#### Synchronize local database and Coinbase history
```ruby
#Run this code if you manually make a trade through the Coinbase website to update your local database
trader = Trader.new
trader.pull_transactions_from_coinbase
```
