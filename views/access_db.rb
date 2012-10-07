require "mysql"
class Mysql
  def access
    m = Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
    an = m.query("SELECT * FROM OR_TEST1")
    n_rows = an.num_rows
    puts "There are #{n_rows} rows in the result set"
    n_rows.times do
        puts an.fetch_row.join("\s")
    end
  rescue Mysql::Error => e
    puts e.errno
    puts e.error
  ensure
    m.close if m
  end
end

object=Mysql.new
object.access

