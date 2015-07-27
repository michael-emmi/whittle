#!/usr/bin/env ruby

require 'optparse'
require_relative 'whittle/version'

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $0} [options] FILE(s)"
  opts.separator ""
  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end
  opts.separator ""
end.parse!

puts "Whittle version #{Whittle::VERSION} copyright (c) 2015, Michael Emmi"
