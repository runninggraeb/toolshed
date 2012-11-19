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
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :index
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/" do
  redirect "/"
end

get "/friends_tools.html" do
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")

    # for other data you can always run fql
    @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
  end
  erb :friends_tools
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/friends_tools.html" do
  redirect "/friends_tools.html"
end

get "/my_tools.html" do
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
    @m = Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
    @all = @m.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@user['id']}'").fetch_row
    if @all
    else
      @m.query "INSERT INTO OR_TEST3 (fid,city,state,count) VALUES('#{@user['id']}','Eugene','OR','1')"
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

# used by Canvas apps - redirect the POST to be a regular GET
post "/my_tools.html" do

  @graph  = Koala::Facebook::API.new(session[:access_token])
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user    = @graph.get_object("me")
  end

  @new=Mysql.new('us-cdbr-east.cleardb.com','a20b915a9b09e5','3dbe3bcc','heroku_6d2c5db5bc2c644')
  @all = @new.query("SELECT * FROM OR_TEST3 WHERE fid = '#{@user['id']}'").fetch_row
  @new.query "DELETE FROM OR_TEST3 WHERE fid = '#{@user['id']}'"

  @count = @all.at(4)

  @enter=1
  @adds=0
  @news=Array.new(@count+5)
  for i in 1..(@count+5)
    if instance_variable_get(":" + "tool_#{@enter}")
      @news[@adds*2]=params[instance_variable_get(":" + "tool_#{@enter}")]
      @news[@adds*2+1]=params[instance_variable_get(":" + "type_#{@enter}")]
      @adds +=1
    end
    @enter +=1
  end
  @city = params[:city]
  @state = params[:state]

  @new.query "INSERT INTO OR_TEST3 (fid,city,state,count,tool1,type1) VALUES('#{@user['id']}','#{@city}','#{@state}','#{@adds}',#{@news})"
  @new.close
  redirect "/my_tools.html"
end

get "/about_us.html" do
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :about_us
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/about_us.html" do
  redirect "/about_us.html"
end

get "/comments.html" do
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  if session[:access_token]
    @user    = @graph.get_object("me")
  end
  erb :comments
end

# used by Canvas apps - redirect the POST to be a regular GET
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
