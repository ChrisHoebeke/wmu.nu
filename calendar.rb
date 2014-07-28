#encoding: UTF-8

require 'rubygems'
require "rubygems"
require "bundler"
Bundler.require :default, (ENV["RACK_ENV"] || "development").to_sym
require 'i18n'
require 'active_support/core_ext'
require 'google/api_client'
require 'json'
require 'rss'
require 'logger'
require 'open-uri'

def logger; settings.logger end

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
  client = build_client 
  calendar = client.discovered_api('calendar', 'v3') 
  status = []
  result = {}
  cals.each do |cal|
    params = {'calendarId' => cal, "orderBy" => "startTime", "singleEvents" => true, "timeMin" => startDate, "timeMax" => endDate }
    
    response = client.execute(:api_method => calendar.events.list, :parameters => params ) #, :authorization => user_credentials)
    next if response.status != 200
    response.data['items'].each do |item|
      item['start']['dateTime'] ||= Chronic.parse("Today at 8am")
      item['end']['dateTime'] ||= Chronic.parse("Today at 5pm")
      
      day = item['start']['dateTime'].wday
      result[day] ||= []
      result[day] << item
    end
    status << response.status
  end
  
  result.each_value { |r| r.sort_by! { |s|  s["start"]["dateTime"] }}
  return status.uniq, result  #.sort_by { |r| r["start"] }
end

  

def build_client(user_email= 'AcademicSchedules@wmu.se')
    key = Google::APIClient::PKCS12.load_key('541ea7336d9c8e88ff7f0d9b08ca55f4e06bd6ab-privatekey.p12', 'notasecret')
    asserter = Google::APIClient::JWTAsserter.new('217488047499-tg0pkabppj2sd7313qjm4tlepfqniqu6@developer.gserviceaccount.com',
        'https://www.googleapis.com/auth/calendar', key)
    client = Google::APIClient.new(:application_name => "World Maritime", :application_version => "0.1")
    client.authorization = asserter.authorize(user_email)
    client.discovered_api('calendar', 'v3')
    client
end


configure do
  
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG
  
  set :logger, logger
  set :public_folder, Proc.new { File.join(root, "static") }
end

get "/campus/today" do
  cache_control :public, max_age: 1800  # 30 mins.
  yesterday = Chronic.parse("yesterday at midnight" ).to_datetime.to_s
  today = Chronic.parse("today at midnight" ).to_datetime.to_s
  status, result = get_events(yesterday, today)
  events = result[DateTime.now.wday]
  events ||= []
  erb :campus, :locals => { :events => events }
end

get "/buses" do
  stopId = params[:stopId]
  stopName = stopId == '80022' ? 'Malmö Tekniska Museet' : 'Malmö Konserthuset'
  result = []
  xml = Nokogiri::XML(open("http://www.labs.skanetrafiken.se/v2.2/stationresults.asp?selPointFrKey=#{stopId}")).remove_namespaces!
  lines = xml.search("//Line")
  lines.each do |l|
    line = "#{l.search('./Name').text}"
    next if  line.length > 2
    terminus = "#{l.search('./Towards').text}"
    time = l.search('./JourneyDateTime').text
    delay = l.search('.//DepTimeDeviation').text.to_i
    arrival = ( ( Time.parse(time) + delay.minutes ) - Time.now ) / 60
    if delay == 0
      status = "in #{arrival.to_i.to_s} minutes (On Time)"
    else
      status = "in #{arrival.to_i.to_s} minutes (Delayed #{delay} minutes)"
    end
    result << { :line => line, :terminus => terminus, :time => time, :delay => delay, :status => status }    
  end
  
  erb :buses, :locals => { :stopId => stopId, :buses => result[0..20], :stopName => stopName } 
end

get "/cph" do
  cache_control :public, max_age: 300  # 30 mins.
  xml = Nokogiri::HTML(open('http://www.cph.dk/en/flight-info/Departures/'))
  xml.search("//a").each { |n| n.remove }
  xml.search(".//button").each { |n| n.remove }
  span_node = Nokogiri::XML::Node.new('span',xml)
  span_node.content = "see more at  "
  link_node = Nokogiri::XML::Node.new('a',xml)
  link_node['href'] = 'http://www.cph.dk/en/flight-info/Departures/'
  link_node.content = 'cph.dk'
  span_node.add_child(link_node)
  if xml.search('.//caption').length > 0 
    xml.search('.//caption').first.content = '' 
    xml.search('.//caption').first.add_child(span_node)
  end 
  table = nil 
  if xml.search('//table').length > 0
    table = xml.search('//table').first
    table["class"] = "table table-striped"
  end
  activate = params[:activate] ? params[:activate] : nil
  erb :cph, :locals => { :table => table, :activate => activate }
end

get '/weather' do
  cache_control :public, max_age: 900  # 30 mins.
  xml = Nokogiri::HTML(open("http://www.yr.no/place/Sweden/Scania/Malm%C3%B6/"))
  forcast = xml.search(".yr-content-stickynav-three-fifths").first
  map = xml.search(".yr-content-stickynav-two-fifths").first
  erb :weather, :locals => { :forcast => forcast, :map => map }
end

get '/facebook' do
  cache_control :public, max_age: 3600  # 30 mins.
  erb :facebook
end

get '/news' do
  cache_control :public, max_age: 3600
  feed = RSS::Parser.parse('http://feeds.feedburner.com/worldmaritimenews/Ltoh?format=xml') 
  erb :news, :locals => { :items => feed.items }
end

get '/kart/*' do
 content_type :json 
  json = JSON.parse(open('http://www.yr.no/kart/FullScreenLegendJson.aspx?kartlag=precipitation_1h_regional&timezone=Europe%2FStockholm&sprak=eng').read)
 json.to_json 
end

get '/_/*' do
  content_type :json
  json = JSON.parse(open('http://www.yr.no/_/wfs/names.aspx?mode=pointpage&srs=EPSG%3A3575&zoom=6&width=1140&height=0&lang=eng&globalid=PunktUtlandet%3A2692969&service=WFS&version=1.1.0&request=GetFeature&outputFormat=json&forecast=1&bbox=-158372,-3774821,554128,-3774821').read)
  json.to_json
end

get '/tz/etcetera' do
  txt = open('http://www.yr.no/tz/etcetera')
  txt
end

get '/tz/europe' do
  txt = open('http://www.yr.no/tz/europe')
  txt
end


get '/' do
  erb :index
  # Fetch list of events on the user's default calandar
end
