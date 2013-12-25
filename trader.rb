require 'colorize'
require 'coinbase'
load 'db.rb'

class Trader
  def initialize (min_percent_gain_for_sale = 0.01, min_percent_drop_for_purchase = 0.01)
    I18n.enforce_available_locales = false

    @db = DatabaseHandler.new
    @coinbase = Coinbase::Client.new ENV['COINBASE_API_KEY']

    @coinbase_flat_fee = 0.15
    @coinbase_percentage_fee = 0.01

    @min_percent_gain = min_percent_gain_for_sale
    @min_percent_drop = min_percent_drop_for_purchase
  end

  def trade
    loop do
      #switch between purchasing and selling
      @db.last_transaction[:type] == :purchase ? consider_sale : consider_purchase
      puts "\n", "*".light_cyan*70, "\n"
      sleep 20
    end
  end

  def bitcoin_balance
    @db.last_transaction[:quantity]
  end

  def consider_sale
    last_purchase = @db.last_transaction "purchase"
    @sell_price = @coinbase.sell_price(bitcoin_balance).to_f
    puts "\nLast purchase was #{last_purchase[:quantity].round 4} BTC for $#{last_purchase[:price].round 4}".light_green
    puts "Can sell #{bitcoin_balance.round 4} BTC for $#{@sell_price.round 4}".light_blue
    #calculate sale profit
    profit = @sell_price - last_purchase[:price]
    min_profit = last_purchase[:price] * @min_percent_gain
    if profit >= min_profit
      puts "Profit $#{profit.round 2} >= $#{min_profit.round 2}".green
      sell
    else
      puts "Profit $#{profit.round 2} < $#{min_profit.round 2}".light_red
    end
  end

  def sell
    puts "SELLING!".green
    puts @coinbase.sell! bitcoin_balance
    @db.insert_transaction @sell_price, bitcoin_balance, :sale
  end

  def consider_purchase
    last_sale = @db.last_transaction "sale"
    buy_price = @coinbase.buy_price 1
    one_btc_price = (buy_price.to_f - @coinbase_flat_fee) / @coinbase_percentage_fee
    #puts "buy price: $#{buy_price}"
    available_funds = last_sale[:price].to_f

    btc_to_purchase = ((available_funds - @coinbase_flat_fee) / @coinbase_percentage_fee) / one_btc_price

    last_sale_dollar_val = last_sale[:price].round 4
    puts "Last sale was #{last_sale[:quantity].round 4} BTC for $#{last_sale_dollar_val}".light_green
    min_amount_to_purchase = last_sale[:quantity] * (1 + @min_percent_drop)
    puts "Can buy #{btc_to_purchase.round 6} BTC for $#{available_funds.round 2}".blue
    if btc_to_purchase >= min_amount_to_purchase
      puts "BTC to purchase #{btc_to_purchase.round 6} BTC >= min of #{min_amount_to_purchase.round 4} BTC".green
      purchase btc_to_purchase, available_funds
    else
      puts "BTC to purchase #{btc_to_purchase.round 6} BTC < min of #{min_amount_to_purchase.round 4} BTC".light_red
    end
  end

  def purchase(btc, cost)
    puts "BUYING!".green
    @db.insert_transaction cost, btc, :purchase
  end

  def pull_transactions_from_coinbase
    @db.clear_database
    @coinbase.transactions.transactions.each do |t|
      type = t.transaction.recipient.email == "das2c3@mail.missouri.edu" ? :purchase : :sale
      cost = /\$(?<amount>\d+\.*\d*)/.match(t.transaction.notes)[:amount].to_f
      @db.insert_transaction cost, t.transaction.amount.to_f.abs, type
    end
  end
end