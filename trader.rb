require 'colorize'
require 'coinbase'
require 'libnotify'
load 'db.rb'

class Trader
  def initialize (options)
    @min_percent_gain = options[:percent_gain_for_sale]
    @min_percent_drop = options[:percent_drop_for_purchase]
    @force_purchase_drop_percent = options[:force_purchase_drop_percent]
    I18n.enforce_available_locales = false

    @coinbase = Coinbase::Client.new ENV['COINBASE_API_KEY']
    @db = DatabaseHandler.new

    @values = []

    @refresh_interval = 25

    @coinbase_flat_fee = 0.15
    @coinbase_percentage_fee = 0.01
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
      sleep @refresh_interval
    end
  end

  def bitcoin_balance
    @db.last_transaction[:quantity]
  end

  def consider_sale
    last_purchase = @db.last_transaction "purchase"
    @sell_price = @coinbase.sell_price(bitcoin_balance).to_f
    puts "\nLast purchase was #{last_purchase[:quantity].btc_round} BTC for $#{last_purchase[:price].usd_round}".light_green

    #calculate sale profit
    profit = @sell_price - last_purchase[:price]
    min_profit = last_purchase[:price] * @min_percent_gain
    target_sale_price = min_profit + last_purchase[:price]

    puts "Can sell #{bitcoin_balance.btc_round} BTC for $#{@sell_price.usd_round} (target is $#{target_sale_price.usd_round})".light_blue
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
    one_btc_price = (buy_price.to_f - @coinbase_flat_fee) / (@coinbase_percentage_fee * 100)
    #puts "the price of 1 btc is... $#{one_btc_price.usd_round}".light_green
    available_funds = last_sale[:price].to_f

    average = @values.inject{ |sum, el| sum + el }.to_f / @values.size
    puts "average: #{average.round 2}".magenta + "  current: #{@one_btc_price_with_fee}".red + "  max: #{@max}".light_cyan
    percent_change = (@one_btc_price_with_fee - @max) / @max
    puts "percent_change: #{(percent_change*100).round 4}%"

    btc_to_purchase = ((available_funds - @coinbase_flat_fee) / @coinbase_percentage_fee) / one_btc_price / 100

    one_btc_price_at_last_sale = (last_sale[:price] + 0.15) / (0.99 * last_sale[:quantity])

    puts "Last sale was #{last_sale[:quantity].btc_round} BTC for $#{last_sale[:price].usd_round} at $#{one_btc_price_at_last_sale.usd_round} per BTC".light_green

    puts "Can buy #{btc_to_purchase.btc_round} BTC for $#{available_funds.usd_round}".blue

    puts "one_btc_price: $#{one_btc_price.usd_round} one_btc_price_at_last_sale: $#{one_btc_price_at_last_sale.btc_round}"
    btc_drop_price_last_transaction = (one_btc_price - one_btc_price_at_last_sale) / one_btc_price_at_last_sale * 100

    puts "The price of one btc has changed #{btc_drop_price_last_transaction.round 2}% since the last sale"

    if percent_change <= -@min_percent_drop or btc_drop_price_last_transaction < @force_purchase_drop_percent * -100
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
    @coinbase.transactions.transactions.reverse.each do |t|
      type = t.transaction.recipient.email == "das2c3@mail.missouri.edu" ? :purchase : :sale
      cost = /\$(?<amount>\d+\.*\d*)/.match(t.transaction.notes)[:amount].to_f
      @db.insert_transaction cost, t.transaction.amount.to_f.abs, type
      sleep 0.5
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