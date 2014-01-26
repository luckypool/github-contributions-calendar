#!/usr/bin/env ruby
# coding: utf-8

require 'uri'
require 'net/https'
require 'json'
require 'date'
require 'rainbow/ext/string'
require 'pp'
require 'text-table'
require 'mixlib/cli'

class GitCalCLI
  include Mixlib::CLI

  option :user,
    :short => "-u USER",
    :long  => "--user USER",
    :required => true,
    :description => "GitHub username"

end

SUNDAY = 0
SATURDAY = 6
INDICATORS = {
  :lv0 => '.'.color('#555555').background(:black),
  :lv1 => 'o'.color('#d6e685').background(:black),
  :lv2 => 'O'.color("#8cc665").background(:black),
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

def convert_to_indicator_level(contribution, max)
  return '0' if contribution <= 0
  return '1' if contribution.between?(0, (max*0.24).to_i)
  return '2' if contribution.between?((max*0.25).to_i, (max*0.36).to_i)
  return '3' if contribution.between?((max*0.37).to_i, (max*0.50).to_i)
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

def generate_calendar_matrix(raw, max_contribution)
  cal = [[]]
  parsed_data = raw.clone

  cal.first.push(parsed_data.first[:month])
  wday = parsed_data.first[:wday]
  (1..wday).each{cal.first.push(nil)}
  (0..(SATURDAY-wday)).to_a.each{
    cal.first.push(convert_to_indicator_level(parsed_data.shift[:contribution], max_contribution))
  }

  while parsed_data.length > 0 do
    week = []
    week.push(parsed_data.first[:month])
    (SUNDAY..SATURDAY).to_a.each do
      contribution = parsed_data.shift[:contribution]
      week.push(convert_to_indicator_level(contribution, max_contribution))
      unless parsed_data.length > 0 then
        (8-week.length).times{week.push(nil)}
        break
      end
    end
    cal.push(week)
  end

  cal.unshift(['','','M','','W','','F',''])
  return cal.transpose
end

def generate_header(row)
  raw_header = row.clone
  initial = [{:value=>raw_header.shift, :colspan=>1, :align=>:left}]
  return raw_header.inject(initial){|header, month|
    if month == header.last[:value] then
      header.last[:colspan]+=1
    else
      header << {:value=>month, :colspan=>1, :align=>:left}
    end
    header
  }
end

def colorize(string)
  return string.chars.map{|c|
    c=~/[0-4]/ ? c.gsub(/[0-4]/, REPLACE_TABLE) : c(c)
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
  cli = GitCalCLI.new()
  cli.parse_options
  calendar_data = get("https://github.com/users/" << cli.config[:user] << "/contributions_calendar_data")

  max_contribution = calendar_data.map{|d| d[1]}.max
  total = calendar_data.map{|d| d[1]}.inject(:+)
  streak = make_streak(calendar_data.map{|d| d[1]})
  streak_max = streak.map{|v| v.first==0 ? 0 : v.length}.max
  current_strek = streak.last.inject(0){|sum,v| sum += v>0 ? 1 : 0}

  parsed_data = parse_calendar_data(calendar_data)
  cal = generate_calendar_matrix(parsed_data, max_contribution)

  column_size = cal.first.length
  header = generate_header(cal.shift)
  footer = [{:value=>'Less  0 1 2 3 4  More', :colspan=>column_size, :align=>:right}]
  cal.unshift(header)
  cal.push(:separator)
  cal.push(footer)

  t = Text::Table.new(
    :rows => cal,
    :horizontal_padding    => 0,
    :vertical_boundary     => ' ',
    :horizontal_boundary   => ' ',
    :boundary_intersection => ' ',
  )

  table_string = colorize(t.to_s)
  print table_string

  t.rows << [total.to_s<<' Total', streak_max.to_s<<' days', current_strek.to_s<<' days'].map{|v|
    {:value => v, :colspan => column_size/3, :align => :center}
  }
  t.rows.last.last[:colspan]+=column_size%3
  t.rows << ['Year of Contributions', 'Longest Streak', 'Current Streak'].map{|v|
    {:value => v, :colspan => column_size/3, :align => :center}
  }
  t.rows.last.last[:colspan]+=column_size%3
  -3.upto(-1){|i| print c(t.to_s.lines[i]) }
end

main()

