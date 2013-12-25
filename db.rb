require "sqlite3"

class DatabaseHandler
  def initialize
    @db = SQLite3::Database.new "bitcoins.db"
    
    rows = @db.execute <<-SQL
      create table if not exists transactions (
        price real,
        quantity real,
        type varchar(10),
        timestamp DATETIME
      );
    SQL
  end

  def list_transactions
    @db.execute( "select * from transactions" ) do |row|
      p row
    end
  end

  def total_profit
    sum = 0
    @db.execute( "select * from transactions" ) do |row|
      if row[2] == "purchase"
        sum -= row[0]
      else
        sum += row[0]
      end
    end
    sum
  end

  def insert_transaction (price, quantity, type)
    @db.execute("INSERT INTO transactions (price, quantity, type, timestamp)
            VALUES (?, ?, ?, datetime('now', 'utc'))", [price, quantity, type.to_s])
  end

  def last_transaction(type=nil)
    query = "select * from transactions"
    query << ' where type = "' + type.to_s + '"' if type
    row = @db.execute( query + " order by timestamp desc limit 1" ).first
    return nil if row == nil
    {
      :price => row[0],
      :quantity => row[1],
      :type => row[2].to_sym
    }
  end

  def clear_database
    @db.execute "delete from transactions"
  end
end