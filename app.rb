require "sinatra"
require "koala"
require "mysql"

enable :sessions
set :raise_errors, false
set :show_exceptions, false

FACEBOOK_SCOPE = 'user_likes,user_photos,user_photo_video_tags'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
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
  @fr_count=0
  @fr_w_count=0
  @l=@fr_app.length
  @list=Array.new(@l)
  @names=Array.new(@l)
  @m = Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
  @all = @m.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@user['id']}'").fetch_row
  @state = @all.at(3)
  @fr_app.each do |friend_result|
    @friend=@fr_app.at(@fr_count)
    @lend=@m.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@friend['uid']}'").fetch_row
    if @lend != nil
      @list[@fr_w_count] = @lend.compact
      @names[@fr_w_count] = @friend['name']
      @fr_w_count +=1
    end
    @fr_count +=1
  end
  @m.close

  @names=@names.compact
  @state_count=1
  @it=0
  @state_list=Array.new(50)

  @template=Array.new(6)
  @template[0]=Array.new(0)
  @template[1]=Array.new(0)
  @template[2]=Array.new(0)
  @template[3]=Array.new(0)
  @template[4]=Array.new(0)
  @template[5]=Array.new(0)

  instance_variable_set(:@state, Array.new(@template))
  @state_list[0]=@state

  for i in 1..@names.length
    @temp_fr=@names.at(@it)
    @temp_inv=@list.at(@it)
    if instance_variable_get("@#{@temp_inv.at(3)}") == nil
      instance_variable_set(:"@#{@temp_inv.at(3)}", Array.new(@template))
      @state_list[@state_count]=@temp_inv.at(3)
      @state_count +=1
    end




    @c=6
    @inv_size=@temp_inv.at(4)

    for i in 1..@inv_size
=begin

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
      if @temp_inv.at(@c) == "other"
        @temp_type=5
      end
      instance_variable_get("@#{@temp_inv.at(3)}")[@temp_type] +=[[@temp_inv.at(@c-1),@temp_fr,@temp_inv.at(2)]]

=end
      @c +=2
    end




    @it +=1

  end


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
    @m = Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
    @all = @m.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@user['id']}'").fetch_row
    if @all
    else
      @m.query "INSERT INTO OR_TEST3 (fid,city,state,count) VALUES('#{@user['id']}','Eugene','OR','0')"
      @all = @m.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@user['id']}'").fetch_row
    end
    @m.close
    @city = @all.at(2)
    @state = @all.at(3)
    @count = @all.at(4)
    @count = @count.to_i

  end
  erb :my_tools
end

post "/my_tools.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @new=Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
  @all = @new.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@user['id']}'").fetch_row

  @count = @all.at(4)
  @count = @count.to_i

  @enter=0
  @adds=0
  @news=Array.new(@count*2+11)
  @labels=Array.new(@count*2+11)
  for i in 1..(@count+5)
    @enter +=1
    @temp=params[:"tool_#{@enter}"]
    if @temp.size > 2
      @news[@adds*2+1] = "'#{@temp}'"
      @temp=params[:"type_#{@enter}"]
      @news[@adds*2+2] = "'#{@temp}'"
      @labels[@adds*2+1]="tool#{@enter}"
      @labels[@adds*2+2]="type#{@enter}"
      @adds +=1
    end
  end

 #Try route matching

  @news=@news[1..(@adds*2)]
  @labels=@labels[1..(@adds*2)]

  @news=@news.join(',')
  @labels=@labels.join(',')

  @city = params[:city]
  @state = params[:state]

  @new.query "DELETE FROM OR_TEST3 WHERE fid = '#{@user['id']}'"
  @new.query "INSERT INTO OR_TEST3 (fid,city,state,count,#{@labels}) VALUES('#{@user['id']}','#{@city}','#{@state}','#{@adds}',#{@news})"

  @new.close
  redirect "/my_tools.html"
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
  redirect "/comments.html"
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
