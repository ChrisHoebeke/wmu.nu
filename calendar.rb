require 'rubygems'
require 'google/api_client'
require 'sinatra'
require 'logger'
require 'chronic'
require 'open-uri'
require 'nokogiri'

enable :sessions

def logger; settings.logger end

def api_client; settings.api_client; end

def calendar_api; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

def cals  
 [
   'wmu.se_2d34303534383532342d333834@resource.calendar.google.com',
   'wmu.se_2d34303337333438322d363532@resource.calendar.google.com',
   'wmu.se_39333138343538362d3434@resource.calendar.google.com',
   'wmu.se_3932373939373633313134@resource.calendar.google.com',
   'wmu.se_3932383538303332383835@resource.calendar.google.com',
   'wmu.se_2d37353437393236312d313034@resource.calendar.google.com',
   'wmu.se_38343837353738392d383336@resource.calendar.google.com',
   'wmu.se_3835323931373238343839@resource.calendar.google.com',
   'wmu.se_2d36363633363032373937@resource.calendar.google.com'
 ]
end

def get_events( startDate, endDate )
  status = []
  result = {}
  cals.each do |cal|
    params = {'calendarId' => cal, "orderBy" => "startTime", "singleEvents" => true, "timeMin" => startDate, "timeMax" => endDate }
    
    response = api_client.execute(:api_method => settings.calendar.events.list, :parameters => params, :authorization => user_credentials)
    response.data['items'].each do |item|
      day = item["start"]["dateTime"].wday
      result[day] ||= []
      result[day] << item
    end
    status << response.status
  end
  result.each_value { |r| r.sort_by! { |s|  s["start"]["dateTime"] }}
  return status.uniq, result  #.sort_by { |r| r["start"] }
end

configure do
  
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG
  
  client = Google::APIClient.new
  client.authorization.client_id = "233199329657-2riv99asskssd6qp8v6d1298na30977s.apps.googleusercontent.com"
  client.authorization.client_secret = "d9TfpdPLNTCq94eJT5v6_YjR"
  client.authorization.scope = 'https://www.googleapis.com/auth/calendar'

  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar
  set :public_folder, Proc.new { File.join(root, "static") }
end

before do
  # Ensure user has authorized the app
  unless user_credentials.access_token || request.path_info =~ /^\/oauth2/
    redirect to('/oauth2authorize')
  end
end

after do
  # Serialize the access/refresh token to the session
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end

get "/week" do
  monday = Chronic.parse('last monday').to_datetime.to_s
  friday = Chronic.parse('this friday').to_datetime.to_s
  status, result = get_events(monday, friday)
  [status.first , {'Content-Type' => 'application/json'}, result.to_json ]
end

get "/today" do
  yesterday = Chronic.parse("yesterday at midnight" ).to_datetime.to_s
  today = Chronic.parse("today at midnight" ).to_datetime.to_s
  status, result = get_events(yesterday, today)
  [status.first , {'Content-Type' => 'application/json'}, result.values.flatten.to_json ]
end

get "/buses" do
  result = []
  xml = Nokogiri::XML(open("http://www.labs.skanetrafiken.se/v2.2/stationresults.asp?selPointFrKey=80022")).remove_namespaces!
  lines = xml.search("//Line")
  lines.each do |l|
    line = "#{l.search('./Name').text}"
    terminus = "#{l.search('./Towards').text}"
    time = l.search('./JourneyDateTime').text
    delay = l.search('.//DepTimeDeviation').text.to_i
    result << { :line => line, :terminus => terminus, :time => time, :delay => delay }    
  end
  
  [200 , {'Content-Type' => 'application/json'}, result.to_json ]
  
end


get '/' do
  erb :index
  # Fetch list of events on the user's default calandar

end
