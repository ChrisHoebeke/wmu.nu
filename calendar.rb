require 'rubygems'
require 'google/api_client'
require 'sinatra'
require 'json'
require 'logger'
require 'chronic'
require 'open-uri'
require 'nokogiri'

enable :sessions

def logger; settings.logger end

def api_client; settings.api_client; end

def calendar_api; settings.calendar; end

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
    
    response = api_client.execute(:api_method => settings.calendar.events.list, :parameters => params ) #, :authorization => user_credentials)
    next if response.status != 200
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

  

def build_client(user_email= 'AcademicSchedules@wmu.se')
    key = Google::APIClient::PKCS12.load_key('541ea7336d9c8e88ff7f0d9b08ca55f4e06bd6ab-privatekey.p12', 'notasecret')
    asserter = Google::APIClient::JWTAsserter.new('217488047499-tg0pkabppj2sd7313qjm4tlepfqniqu6@developer.gserviceaccount.com',
        'https://www.googleapis.com/auth/calendar', key)
    client = Google::APIClient.new(:application_name => "World Maritime", :application_version => "0.1")
    client.authorization = asserter.authorize(user_email)
    client
end

configure do
  
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG
  
  client = build_client()
  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar
  set :public_folder, Proc.new { File.join(root, "static") }
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
  stopId = params[:stopId]
  result = []
  xml = Nokogiri::XML(open("http://www.labs.skanetrafiken.se/v2.2/stationresults.asp?selPointFrKey=#{stopId}")).remove_namespaces!
  lines = xml.search("//Line")
  lines.each do |l|
    line = "#{l.search('./Name').text}"
    # next unless  line == "3" or line == "32"
    terminus = "#{l.search('./Towards').text}"
    time = l.search('./JourneyDateTime').text
    delay = l.search('.//DepTimeDeviation').text.to_i
    result << { :line => line, :terminus => terminus, :time => time, :delay => delay }    
  end
  
  [200 , {'Content-Type' => 'application/json'}, result[0..12].to_json ]
  
end

get "/cph" do
  xml = Nokogiri::HTML(open('http://www.cph.dk/CPH/UK/MAIN/Flight+Timetables/International+Departures.htm'))
  xml.search("//a").each { |n| n.remove }
  xml.search(".//td[contains(text(), 'SMS')]").each { |n| n.remove } 
  table = xml.search('//table')[3]
  table["class"] = "table table-striped"
  [200, { 'Content-Type' => 'text/html'}, table.to_html ]
end


get '/' do
  erb :index
  # Fetch list of events on the user's default calandar
end
