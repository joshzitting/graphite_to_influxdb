#!/usr/bin/env ruby
#
# Postfix Mailq metrics
# ===
#
# Fetch message count metrics from Postfix Mailq.
#
# Example
# -------
#
# $ ./worker.rb -g 10.128.39.4 -i 10.129.21.217 -h 5min
# 
#
# Acknowledgements
# ----------------
#
# Copyright 2014 Matt Mencel <https://github.com/MattMencel>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'net/http'
require 'uri'
require 'json'
# require 'awesome_print' uncomment this if you will be using ap for debugging

class GraphiteToInflux < Sensu::Plugin::Metric::CLI::Graphite
  option :graphite,
    short: '-g graphite',
    long: '--graphite graphite',
    description: 'Graphite hostname/ipaddress'

  # option :target,
  #   short: '-t graphite_prod',
  #   long: '--target graphite_prod',
  #   description: 'specific target to pull from graphite',
  #   default: nil

  option :history,
    short: '-h 1y',
    long: '--history',
    description: 'how far back to query, 1min,1h,1w,1mon,1y',
    default: '6mon'

  option :influxdb,
    short: '-i influx',
    long: '--influx influx',
    description: 'influx hostname/ipaddress'

  option :rest,
    short: '-r 5',
    long: '--rest 5',
    description: 'seconds to slepp between each meausrement. use this if your avaialbe resources get scarce',
    default: 1

  option :p,
    description: 'Graphite web port',
    short: '-p port',
    long: '--port port',
    default: 80


  option :in_port,
    description: 'influxdb lisenting server port',
    short: '-P port',
    long: '--Port port',
    default: 2003

  def open(url)
    Net::HTTP.get(URI.parse(url))
  end

  def run
    targets = open("http://#{config[:graphite]}/metrics/index.json")
    # ap JSON.parse(targets), { :index => false, :plain => true, :indent => 2 } # this will print the output very nicely
    targets_hash = JSON.parse(targets)
    #   ap JSON.parse(targets), { :index => false, :plain => true, :indent => 2 } # this will print the output very nicely

    targets_hash.each do |target|
      puts "Currently Loading #{target}"
      beginning_time = Time.now
      metric = open("http://#{config[:graphite]}/render?target=#{target}&format=json&from=-#{config[:history]}&until=-1min")
      # ap JSON.parse(metric), { :index => false, :plain => true, :indent => 2 }
      gq_time = Time.now #graphite querry time

      metric_hash = JSON.parse(metric)
      sock = TCPSocket.open("#{config[:influxdb]}", config[:in_port])
      ip_time = Time.now #influx push time

      count = 0
      metric_hash[0]['datapoints'].each do |value,tstamp|
        unless value.nil? || tstamp.nil?
          sock.write("#{target} #{value} #{tstamp} \n" )
          count +=1
        end
      end
      sock.close
      end_time = Time.now
      puts "Finished #{target} Wrote #{count} Records in #{(end_time - beginning_time)} seconds Graphite querry took #{(gq_time - beginning_time)} seconds influx push took #{(end_time - ip_time)} seconds"
      sleep(config[:rest].to_i)
    end
    ok
  end
end
