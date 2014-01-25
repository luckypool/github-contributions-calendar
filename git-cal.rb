#!/usr/bin/env ruby
# coding: utf-8

require 'uri'
require 'net/https'
require 'json'
require 'date'
require 'rainbow/ext/string'
require 'pp'
require 'text-table'

SUNDAY = 0
SATURDAY = 6
INDICATORS = {
  :lv0 => '.'.color('#555555').background(:black),
  :lv1 => 'o'.color('#d6e685').background(:black),
  :lv2 => 'o'.color("#8cc665").background(:black),
  :lv3 => 'O'.color("#44a340").background(:black),
  :lv4 => '@'.color("#1e6823").background(:black),
}
REPLACE_TABLE = {
  '0' => INDICATORS[:lv0],
  '1' => INDICATORS[:lv1],
  '2' => INDICATORS[:lv2],
  '3' => INDICATORS[:lv3],
  '4' => INDICATORS[:lv4],
}

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

def convert_to_indicator_level(contribution)
  return '0' if contribution <= 0
  return '1' if contribution.between?(1, 4)
  return '2' if contribution.between?(5, 8)
  return '3' if contribution.between?(9, 12)
  return '4'
end

def parse_calendar_data(calendar_data)
  return calendar_data.map{|data|
    date = Date.parse(data.first)
    {
      :month => date.strftime('%b'),
      :wday => date.wday,
      :contribution => data[1]
    }
  }
end

def generate_calendar_matrix(raw)
  cal = [[]]
  parsed_data = raw.clone

  cal.first.push(parsed_data.first[:month])
  wday = parsed_data.first[:wday]
  (1..wday).each{cal.first.push(nil)}
  (0..(SATURDAY-wday)).to_a.each{
    cal.first.push(convert_to_indicator_level(parsed_data.shift[:contribution]))
  }

  while parsed_data.length > 0 do
    week = []
    week.push(parsed_data.first[:month])
    (SUNDAY..SATURDAY).to_a.each do
      contribution = parsed_data.shift[:contribution]
      week.push(convert_to_indicator_level(contribution))
      unless parsed_data.length > 0 then
        (1..week.length-(7+1)).to_a.each{week.push(nil)}
        break
      end
    end
    cal.push(week)
  end

  cal.unshift(['','','M','','W','','F',''])
  return cal.transpose
end

def generate_header(row)
  header = []
  curr_month = 0
  row.each do |month|
    if month == curr_month then
      header.last[:colspan]+=1
    else
      curr_month = month
      header.push({:value=>curr_month, :colspan=>1, :align=>:left})
    end
  end
  return header
end

def colorize(string)
  return string.split(//).map{|c|
    if (c=~/[0-4]/) then
      c.gsub(/[0-4]/, REPLACE_TABLE)
    else
      c(c)
    end
  }.join()
end

def c(str)
  return str.color('#999999').background(:black)
end

def make_streak(list)
  return list.inject([[]]){|r,v|
    if r.last.last != 0 and v!=0 then
      r.last << v
    else
      r << [v]
    end
    r
  }
end

def main
  calendar_data = get("https://github.com/users/luckypool/contributions_calendar_data")

  total = calendar_data.map{|d| d[1]}.inject(:+)
  streak = make_streak(calendar_data.map{|d| d[1]})
  streak_max = streak.map{|v| v.length}.max
  current_strek = streak.last.inject(:+)

  parsed_data = parse_calendar_data(calendar_data)
  cal = generate_calendar_matrix(parsed_data)

  column_size = cal.first.length
  header = generate_header(cal.shift)
  footer = [{:value=>'Less 0 1 2 3 4 More', :colspan=>column_size, :align=>:right}]
  cal.unshift(header)
  cal.push(:separator)
  cal.push(footer)

  t = Text::Table.new(
    :rows => cal,
    :horizontal_padding    => 0,
    :vertical_boundary     => ' ',
    :horizontal_boundary   => ' ',
    :boundary_intersection => ' ',
  );

  print colorize(t.to_s)

  puts sprintf('-->  %d Total [Year of Contributions] ', total)
  puts sprintf('-->  %d days [Longest Streak] ', streak_max)
  puts sprintf('-->  %d days [Current Streak] ', current_strek)
end

main()

