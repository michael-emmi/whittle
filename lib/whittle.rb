#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'colorize'
require_relative 'whittle/version'

def version
  "Whittle version #{Whittle::VERSION} copyright (c) 2015, Michael Emmi"
end

def error(msg)
  puts "Error: #{msg}".red
  exit(-1)
end

def warn(msg)
  puts "Warning: #{msg}".yellow
end

class Naming
  def initialize(directory, original)
    @directory = directory
    @basename = File.basename(original,'.*')
    @extname = File.extname(original)
  end
  def file(index)
    File.join(@directory,"#{@basename}.#{index}#{@extname}")
  end
  def result(index)
    File.join(@directory,"#{@basename}.#{index}.out")
  end
  def count(index)
    File.join(@directory,"#{@basename}.#{index}.count")
  end
end

def run(command,result_file)
  `#{command} > #{result_file}`
end

@verbose = false
@efile = :@FILE
@eseed = :@SEED
@random = false
@dir = File.join(Dir.pwd,"WHITTLED")

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $0} [options] FILE(s)"
  opts.separator ""
  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    @verbose = v
  end
  opts.on("-q", "--query CMD", "The query command") do |cmd|
    @query = cmd
  end
  opts.on("-c", "--count CMD", "The seed-counting command") do |cmd|
    @count = cmd
  end
  opts.on("-r", "--reduce CMD", "The reduce command") do |cmd|
    @reduce = cmd
  end
  opts.on("-f", "--file EXPR", "File expression (default #{@efile})") do |e|
    @efile = e
  end
  opts.on("-s", "--seed EXPR", "Seed expression (default #{@eseed})") do |e|
    @eseed = e
  end
  opts.on("--[no-]random-seed", "Use random seeding?") do |r|
    @random = r
  end
  opts.on("-o", "--output-dir", "Output directory") do |d|
    @dir = d
  end
  opts.separator ""
end.parse!

begin

  puts version.bold
  error "single input file required" unless ARGV.count == 1
  error "input file does not exist" unless File.exist?(ARGV.first)
  error "must specify a query method" unless @query
  error "must specify a reduce method" unless @reduce
  warn "termination is not guaranteed without seed counting" unless @count
  error "output directory #{@dir} already exists" if File.exist?(@dir)
  @input = ARGV.first

  @namer = Naming.new(@dir,@input)
  FileUtils.mkdir_p @dir
  FileUtils.cp(@input,@namer.file(0))

  puts "Generating reference query result"
  run(@query.gsub(/#{@efile}/,@namer.file(0)), @namer.result(0))

  index = 1

  puts "Counting seeds"
  run(@count.gsub(/#{@efile}/,@namer.file(0)), @namer.count(0))
  seeds = File.read(@namer.count(0)).to_i.times.to_a

  loop do

    if seeds.empty?
      puts "Exhausted all known reductions"
      break
    end

    seed = @random ? seeds.delete_at(rand(seeds.count)) : seeds.shift

    puts "generating new reduction (seed = #{seed})"
    run(@reduce.
      gsub(/#{@efile}/,@namer.file(index-1)).
      gsub(/#{@eseed}/,seed.to_s), @namer.file(index))

    puts "generating query result"
    run(@query.gsub(/#{@efile}/,@namer.file(index)), @namer.result(index))

    if FileUtils.identical?(@namer.result(0),@namer.result(index))
      puts "obtained new reduction (number #{index})"

      puts "Counting seeds"
      run(@count.gsub(/#{@efile}/,@namer.file(index)), @namer.count(index))
      seeds = File.read(@namer.count(index)).to_i.times.to_a

      index += 1
    else
      puts "reduction query result differs, retrying"
    end
  end
ensure

end
