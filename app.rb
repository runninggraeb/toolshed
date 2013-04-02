require "sinatra"
require "koala"
require "mysql"
require "newrelic_rpm"

enable :sessions
set :raise_errors, false
set :show_exceptions, false
FACEBOOK_SCOPE = ''

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set  and  with your app credentials")
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
end

helpers do
  def host
    request.env['HTTP_HOST']
  end

  def scheme
    request.scheme
  end

  def url_no_scheme(path = '')
    "//#{host}#{path}"
  end

  def url(path = '')
    "#{scheme}://#{host}#{path}"
  end

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end

  def access_token_from_cookie
    authenticator.get_user_info_from_cookies(request.cookies)['access_token']
  rescue => err
    warn err.message
  end

  def access_token
    session[:access_token] || access_token_from_cookie
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

end

# the facebook session expired! reset ours and restart the process
error(Koala::Facebook::APIError) do
  session[:access_token] = nil
  redirect "/auth/facebook"
end


get "/" do

  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :index
end

post "/" do
  redirect "/"
end






get "/friends_tools.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")

    @fr_app = @graph.fql_query("SELECT uid, name, is_app_user FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
  end

  #initiate array
  @fr_w_count=0
  @l=@fr_app.length
  @list=Array.new(@l)
  @names=Array.new(@l)
  @m = Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  @fr_app.each do |friend_result|
    @lend=@m.query("SELECT * FROM Final_uni WHERE fid = '#{friend_result['uid']}'").fetch_row
    if @lend != nil
      if @lend.at(2).length>1
        @list[@fr_w_count] = @lend.compact
        @names[@fr_w_count] = friend_result['name']
        @fr_w_count +=1
      end
    end
  end
  @m.close

  @names=@names.compact
  @state_count=0

  @state_list=Array.new(50)

  @template=Array.new(7)
  @template[0]=Array.new(0)
  @template[1]=Array.new(0)
  @template[2]=Array.new(0)
  @template[3]=Array.new(0)
  @template[4]=Array.new(0)
  @template[5]=Array.new(0)
  @template[6]=Array.new(0)

  if @all != nil
    if @all.at(2).length>1
      @state_list[0]=@all.at(3)
      instance_variable_set(:"@#{@all.at(3)}", Array.new(@template))
      @state_count +=1
    end
  end

  @it=0
  for i in 1..@names.length
    @temp_fr=@names.at(@it)
    @temp_inv=@list.at(@it)
    if instance_variable_get("@#{@temp_inv.at(3)}") == nil
      if @temp_inv.length >5
        instance_variable_set(:"@#{@temp_inv.at(3)}", Array.new(@template))
        @state_list[@state_count]=@temp_inv.at(3)
        @state_count +=1
      end
    end
    @c=6
    @inv_size=@temp_inv.at(4)
    @inv_size=@inv_size.to_i
    for i in 1..@inv_size
      if @temp_inv.at(@c) == "carpentry"
        @temp_type=0
      end
      if @temp_inv.at(@c) == "plumbing"
        @temp_type=1
      end
      if @temp_inv.at(@c) == "electrical"
        @temp_type=2
      end
      if @temp_inv.at(@c) == "yard_work"
        @temp_type=3
      end
      if @temp_inv.at(@c) == "painting"
        @temp_type=4
      end
      if @temp_inv.at(@c) == "food_processing"
        @temp_type=5
      end
      if @temp_inv.at(@c) == "other"
        @temp_type=6
      end
      instance_variable_get("@#{@temp_inv.at(3)}")[@temp_type] +=[[@temp_inv.at(@c-1),@temp_fr,@temp_inv.at(2)]]
      @c +=2
    end
    @it +=1
  end

  @state_list=@state_list.compact
  @state_number=@state_list.length

  erb :friends_tools
end

post "/friends_tools.html" do
  redirect "/friends_tools.html"
end






get "/my_tools.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @m = Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row

  if @all
  elsif @user['location']
    @location_t=@user['location']
    @location=@location_t['name'].rpartition(", ")
    @city = @location.first
    @state = @location.last
    @m.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','0')"
    @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  elsif @user['hometown']
    @location_t=@user['hometown']
    @location=@location_t['name'].rpartition(", ")
    @city = @location.first
    @state = @location.last
    @m.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','0')"
    @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  else
    @city = " "
    @state = " "
    @m.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','0')"
    @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  end
  @m.close

  @city = @all.at(2)
  @state = @all.at(3)
  @count = @all.at(4)
  @count = @count.to_i

  erb :my_tools
end

post "/my_tools.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @new=Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @new.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row

  @count = @all.at(4)
  @count = @count.to_i
 
  @enter=0
  @adds=0
  @news=Array.new(@count*2+11)
  @labels=Array.new(@count*2+11)
  for i in 1..(@count+5)
    @enter +=1
    if params[:"tool_#{@enter}"]
      @temp=params[:"tool_#{@enter}"]
      @temp=h(@temp)
      @temp=@temp.strip
      if @temp.size > 2
        @news[@adds*2+1] = "'#{@temp}'"
        @temp=params[:"type_#{@enter}"]
        @temp=h(@temp)
        @news[@adds*2+2] = "'#{@temp}'"
        @labels[@adds*2+1]="tool#{@enter}"
        @labels[@adds*2+2]="type#{@enter}"
        @adds +=1
      end
    end
  end

 #Try route matching

  @city = params[:city]
  @city = h(@city)
  @city = @city.strip
  @state = params[:state]
  @state = h(@state)

  if @adds > 0
    @news=@news[1..(@adds*2)]
    @labels=@labels[1..(@adds*2)]

    @news=@news.join(',')
    @labels=@labels.join(',')

    @new.query "DELETE FROM Final_uni WHERE fid = '#{@user['id']}'"
    @new.query "INSERT INTO Final_uni (fid,city,state,count,#{@labels}) VALUES('#{@user['id']}','#{@city}','#{@state}','#{@adds}',#{@news})"
  else
    @new.query "DELETE FROM Final_uni WHERE fid = '#{@user['id']}'"
    @new.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','#{@adds}')"
  end
    
  @new.close
  if @city.length<2
    redirect "/add_location.html"
  elsif @state.length<2
    redirect "/add_location.html"
  else
    redirect "/my_tools_g.html"
  end
end





get "/my_tools_g.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @m = Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row

  if @all
  elsif @user['location']
    @location_t=@user['location']
    @location=@location_t['name'].rpartition(", ")
    @city = @location.first
    @state = @location.last
    @m.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','0')"
    @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  elsif @user['hometown']
    @location_t=@user['hometown']
    @location=@location_t['name'].rpartition(", ")
    @city = @location.first
    @state = @location.last
    @m.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','0')"
    @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  else
    @city = " "
    @state = " "
    @m.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','0')"
    @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  end
  @m.close

  @city = @all.at(2)
  @state = @all.at(3)
  @count = @all.at(4)
  @count = @count.to_i

  erb :my_tools_gino
end

post "/my_tools_g.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @new=Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @new.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row

  @count = @all.at(4)
  @count = @count.to_i
 
  @enter=0
  @adds=0
  @news=Array.new(@count*2+11)
  @labels=Array.new(@count*2+11)
  for i in 1..(@count+5)
    @enter +=1
    if params[:"tool_#{@enter}"]
      @temp=params[:"tool_#{@enter}"]
      @temp=h(@temp)
      @temp=@temp.strip
      if @temp.size > 2
        @news[@adds*2+1] = "'#{@temp}'"
        @temp=params[:"type_#{@enter}"]
        @temp=h(@temp)
        @news[@adds*2+2] = "'#{@temp}'"
        @labels[@adds*2+1]="tool#{@enter}"
        @labels[@adds*2+2]="type#{@enter}"
        @adds +=1
      end
    end
  end

 #Try route matching

  @city = params[:city]
  @city = h(@city)
  @city = @city.strip
  @state = params[:state]
  @state = h(@state)

  if @adds > 0
    @news=@news[1..(@adds*2)]
    @labels=@labels[1..(@adds*2)]

    @news=@news.join(',')
    @labels=@labels.join(',')

    @new.query "DELETE FROM Final_uni WHERE fid = '#{@user['id']}'"
    @new.query "INSERT INTO Final_uni (fid,city,state,count,#{@labels}) VALUES('#{@user['id']}','#{@city}','#{@state}','#{@adds}',#{@news})"
  else
    @new.query "DELETE FROM Final_uni WHERE fid = '#{@user['id']}'"
    @new.query "INSERT INTO Final_uni (fid,city,state,count) VALUES('#{@user['id']}','#{@city}','#{@state}','#{@adds}')"
  end
  
  @new.close
  if @city.length<2
    redirect "/add_location.html"
  elsif @state.length<2
    redirect "/add_location.html"
  else
    redirect "/my_tools_g.html"
  end
end






get "/add_location.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @m = Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @m.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  @m.close

  @city=@all.at(2)
  @state=@all.at(3)

  erb :add_location
end

post "/add_location.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @city = params[:city]
  @city = h(@city)
  @city = @city.strip
  @state = params[:state]
  @state = h(@state)


  @new=Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @all = @new.query("SELECT * FROM Final_uni WHERE fid = '#{@user['id']}'").fetch_row
  @all[2] = @city
  @all[3] = @state
  @count = @all.at(4).to_i

  @col=Array.new(@count*2+4)
  @col[0]="fid"
  @col[1]="city"
  @col[2]="state"
  @col[3]="count"
  @enter = 0
  for i in 1..(@count)
    @enter +=1
    @col[@enter*2+2]="tool#{@enter}"
    @col[@enter*2+3]="type#{@enter}"
  end
  @col=@col.join(',')
  @ent=0
  @adds=Array.new(@count*2+4)
  for i in 1..(@count*2+4)
    @temp=@all.at(@ent+1)
    @adds[@ent]="'#{@temp}'"
    @ent +=1
  end
  @adds=@adds.join(',')

  @new.query "DELETE FROM Final_uni WHERE fid = '#{@user['id']}'"
  @new.query "INSERT INTO Final_uni (#{@col}) VALUES(#{@adds})"
  @new.close


  if @city.length<2
    redirect "/add_location.html"
  elsif @state.length<2
    redirect "/add_location.html"
  else
    redirect "/my_tools.html"
  end
end





get "/about_us.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :about_us
end

post "/about_us.html" do
  redirect "/about_us.html"
end



get "/comments.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :comments
end

post "/comments.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  @t=Time.now
  @time="#{@t.day}-#{@t.month}-#{@t.year}"
  @comment=params[:comment]
  @comment=h(@comment)
  @new=Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @new.query "INSERT INTO Comments (fid,name,date,comment) VALUES('#{@user['id']}','#{@user['name']}','#{@time}','#{@comment}')"
  @new.close

  redirect "/comment_thanks.html"
end

get "/comment_thanks.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :comment_thanks
end

post "/comment_thanks.html" do
  redirect "/comment_thanks.html"
end


get "/ad_page.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :ad_page
end

post "/ad_page.html" do
  @graph  = Koala::Facebook::API.new(session[:access_token])
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  @t=Time.now
  @time="#{@t.day}-#{@t.month}-#{@t.year}"
  @slogan=params[:slogan]
  @slogan=h(@slogan)
  @slogan_info=params[:slogan_info]
  @slogan_info=h(@slogan_info)
  @new=Mysql.new('us-cdbr-east-03.cleardb.com','b5cfa774c8e05b','b31600cc','heroku_b8938d7fd4dcc72')
  @new.query "INSERT INTO Ad (fid,name,date,slogan,slogan_info) VALUES('#{@user['id']}','#{@user['name']}','#{@time}','#{@slogan}','#{@slogan_info}')"
  @new.close
  redirect "/ad_thanks.html"
end

get "/ad_thanks.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])

  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :ad_thanks
end

post "/ad_thanks.html" do
  redirect "/ad_thanks.html"
end



# used to close the browser window opened to post to wall/send to friends
get "/close" do
  "<body onload='window.close();'/>"
end

get "/sign_out" do
  session[:access_token] = nil
  redirect '/'
end

get "/auth/facebook" do
  session[:access_token] = nil
  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
end



get '/auth/facebook/callback' do
  session[:access_token] = authenticator.get_access_token(params[:code])
  redirect '/'
end














