require 'colorize'
require 'coinbase'
require 'libnotify'
load 'db.rb'

class Trader
  def initialize (min_percent_gain_for_sale = 0.01, min_percent_drop_for_purchase = 0.01)
    I18n.enforce_available_locales = false

    @db = DatabaseHandler.new
    @coinbase = Coinbase::Client.new ENV['COINBASE_API_KEY']

    @values = []

    @coinbase_flat_fee = 0.15
    @coinbase_percentage_fee = 0.01

    @min_percent_gain = min_percent_gain_for_sale
    @min_percent_drop = min_percent_drop_for_purchase
  end

  def addPrice(price)
    @values << price
    @values.shift if @values.length > 80
    @max = @values.max
  end

  def trade
    loop do
      #record the current purchase price
      @one_btc_price_with_fee = @coinbase.buy_price 1
      addPrice @one_btc_price_with_fee

      #switch between purchasing and selling
      @db.last_transaction[:type] == :purchase ? consider_sale : consider_purchase
      puts "\n", "*".light_cyan*70, "\n"
      sleep 30
    end
  end

  def bitcoin_balance
    @db.last_transaction[:quantity]
  end

  def consider_sale
    last_purchase = @db.last_transaction "purchase"
    @sell_price = @coinbase.sell_price(bitcoin_balance).to_f
    puts "\nLast purchase was #{last_purchase[:quantity].btc_round} BTC for $#{last_purchase[:price].usd_round}".light_green
    puts "Can sell #{bitcoin_balance.btc_round} BTC for $#{@sell_price.usd_round}".light_blue
    #calculate sale profit
    profit = @sell_price - last_purchase[:price]
    min_profit = last_purchase[:price] * @min_percent_gain
    if profit >= min_profit
      puts "Profit $#{profit.usd_round} >= $#{min_profit.usd_round}".green
      sell
    else
      puts "Profit $#{profit.usd_round} < $#{min_profit.usd_round}".light_red
    end
  end

  def sell
    puts "SELLING!".green
    puts @coinbase.sell! bitcoin_balance
    @db.insert_transaction @sell_price, bitcoin_balance, :sale
    Libnotify.show(:body => "#{bitcoin_balance.btc_round} BTC were just sold for $#{@sell_price.usd_round}", :summary => "Bitcoins were sold!", :timeout => 2)
  end

  def consider_purchase
    last_sale = @db.last_transaction "sale"
    buy_price = @one_btc_price_with_fee
    one_btc_price = (buy_price.to_f - @coinbase_flat_fee) / @coinbase_percentage_fee
    available_funds = last_sale[:price].to_f

    average = @values.inject{ |sum, el| sum + el }.to_f / @values.size
    puts "average: #{average.round 2}".magenta + "  current: #{@one_btc_price_with_fee}".red + "  max: #{@max}".light_cyan
    percent_change = (@one_btc_price_with_fee - @max) / @max
    puts "percent_change: #{(percent_change*100).round 4}%"

    btc_to_purchase = ((available_funds - @coinbase_flat_fee) / @coinbase_percentage_fee) / one_btc_price

    puts "Last sale was #{last_sale[:quantity].btc_round} BTC for $#{last_sale[:price].usd_round}".light_green

    puts "Can buy #{btc_to_purchase.btc_round} BTC for $#{available_funds.usd_round}".blue

    if percent_change <= -@min_percent_drop
      purchase btc_to_purchase, available_funds
    end
  end

  def purchase(btc, cost)
    puts "BUYING!".green
    puts @coinbase.buy! btc
    @db.insert_transaction cost, btc, :purchase
    Libnotify.show(:body => "#{btc.btc_round} BTC were just purchased for $#{cost.usd_round}", :summary => "Bitcoins were purchased!", :timeout => 2)
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

class Float
  def btc_round
    self.round 6
  end
  def usd_round
    self.round 2
  end
end