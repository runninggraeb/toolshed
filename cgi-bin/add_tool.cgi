require "cgi"
require "mysql"

query=CGI.new
query=CGI.new
new=Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
new.query "INSERT INTO OR_TEST3 (fid,city,state,count,tool1,type1) VALUES('700630645','Eugene','OR','1','#{query[tool_1]}','Other')"
new.close

puts "Content-Type: text/html"
puts
puts "<html>"
puts "<body>"
puts "<h1>Hello Ruby!</h1>"
puts "</body>"
puts "</html>"
