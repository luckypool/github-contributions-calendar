#!/usr/bin/env ruby
# coding: utf-8
require 'uri'
require 'net/https'
require 'json'
require 'date'
require 'rainbow/ext/string'
require 'pp'

def get(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  end
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  JSON.parse(response.body)
end

calendar_data = get("https://github.com/users/luckypool/contributions_calendar_data")

toal = calendar_data.map{ |data| data[1] }.reduce(&:+)

parsed_data = calendar_data.map do |data|
  date = Date.parse(data[0])
  {
    :month => date.month,
    :wday => date.wday,
    :contributions => data[1]
  }
end

cal = [[]]
while parsed_data[0][:wday] != 0 do
  data = parsed_data.shift
  cal[0].push(data[:contributions])
end

(2..(8-cal[0].length)).to_a.each do
  cal[0].unshift(nil)
end
cal[0].unshift(parsed_data[0][:month])

while parsed_data.length > 0 do
  week = []
  week.push(data[:month])
  (1..7).to_a.each do
    data = parsed_data.shift
    week.push(data[:contributions])
    unless parsed_data.length > 0 then
      break
    end
  end
  cal.push(week)
end

(1..(8-cal[-1].length)).to_a.each do
  cal[-1].push(nil)
end

indicator = [
  ' .'.color('#555555').background(:black),
  ' o'.color('#d6e685').background(:black),
  ' o'.color("#8cc665").background(:black),
  ' o'.color("#44a340").background(:black), #.bright.blink,
  ' o'.color("#1e6823").background(:black) #.bright.blink
]


parsed_cal = cal.transpose

puts ''

month_row = parsed_cal.shift
curr_month = 0
print '     '.background(:black)
while month_row.length > 0 do
  month = month_row.shift
  if month == curr_month then
    print '  '.background(:black)
  else
    curr_month = month
    print sprintf("%2d",month).color("#aaaaaa").background(:black)
  end
end
puts ' '.background(:black)


days = %w(Sun Mon Tue Wed Thr Fri Sat)
parsed_cal.each do |row|
  print sprintf(" %s ",days.shift).color("#aaaaaa").background(:black)
  row.each do |contribution|
    unless contribution then
      print '  '.background(:black)
    else
      if contribution < 1 then
        print indicator[0]
      elsif contribution < 5 then
        print indicator[1]
      elsif contribution < 8 then
        print indicator[2]
      elsif contribution < 11 then
        print indicator[3]
      else
        print indicator[4]
      end
    end
  end
  puts ' '.background(:black)
end

puts ''
print ' less '
indicator.each{|i| print i}
puts ' more'

puts ''
puts sprintf(" Total: %s [commits/year]", toal)

puts ''
