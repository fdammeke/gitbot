#!/usr/bin/env ruby

require "rubygems"
require "date"
require "cinch"
require "sinatra"
require "yaml"
require "json"

config_file = ARGV[0]
if not File.exists? config_file
  puts "Can't find config file #{config_file}"
  puts "Either create it or specify another config file with: #{File.basename $0} [CONFIG]"
  exit
end

$config = YAML.load_file config_file

$bot = Cinch::Bot.new do
  configure do |c|
    c.nick = $config["irc"]["nick"]
    c.user = "gitbot"
    c.realname = "GitBot"
    c.server = $config["irc"]["server"]
    c.port = $config["irc"]["port"]
    c.channels = $config["irc"]["channels"]
  end
end

Thread.new do
  $bot.start
end

def say(repo,msg)
  $config["irc"]["channels"].each do |chan|
    unless $config["filters"].include? chan and not $config["filters"][chan].include? repo
      $bot.Channel(chan).send msg
    end
  end
end

configure do
  set :bind, $config["http"]["host"]
  set :port, $config["http"]["port"]
  set :logging, true
  set :dump_errors, true
  set :lock, true
end

get "/" do
  "GitBot lives here. Direct your hooks to /github/."
end

post "/github/" do
  p params[:payload]
  push = JSON.parse(params[:payload])

  repo = push["repository"]["name"]
  branch = push["ref"].gsub(/^refs\/heads\//,"")

  # sort commits by timestamp
  push["commits"].sort! do |a,b|
    ta = tb = nil
    begin
      ta = DateTime.parse(a["timestamp"])
    rescue ArgumentError
      ta = Time.at(a["timestamp"].to_i)
    end

    begin
      tb = DateTime.parse(b["timestamp"])
    rescue ArgumentError
      tb = Time.at(b["timestamp"].to_i)
    end
    
    ta <=> tb
  end

  # curl -i http://git.io -F "url=https://github.com/..."
  # output one commit
  push["commits"][0..0].each do |c|
    if push["commits"].length-1 > 0
      say repo, "\0030#{repo}:\0037 #{c["author"]["name"]}\003 * #{branch}\0033: #{c["message"]} (+#{push["commits"].length-1} more commits...) - #{c["url"]}\003"
    else
      say repo, "\0030#{repo}:\0037 #{c["author"]["name"]}\003 * #{branch}\0033: #{c["message"]} - #{c["url"]}\003"
    end
  end

  push.inspect
end
