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
    FileUtils.mkdir_p @directory
    FileUtils.cp(original,reduction(0))
  end
  def reduction(index)
    File.join(@directory,"#{@basename}.#{index}#{@extname}")
  end
  def result(index)
    File.join(@directory,"#{@basename}.#{index}.out")
  end
  def count(index)
    File.join(@directory,"#{@basename}.#{index}.count")
  end
end

class Generator
  def initialize(naming, query, reduce, count, file_expr, seed_expr)
    @naming = naming
    @query = query
    @reduce = reduce
    @count = count
    @file_expr = file_expr
    @seed_expr = seed_expr
  end
  def query(index)
    command = @query.gsub(/#{@file_expr}/, @naming.reduction(index))
    run(command, @naming.result(index))
    FileUtils.identical?(@naming.result(0), @naming.result(index))
  end
  def reduce(index, seed)
    command = @reduce.
      gsub(/#{@file_expr}/, @naming.reduction(index-1)).
      gsub(/#{@seed_expr}/, seed.to_s)
    run(command, @naming.reduction(index))
  end
  def count(index)
    command = @count.gsub(/#{@file_expr}/, @naming.reduction(index))
    run(command, @naming.count(index))
    File.read(@naming.count(index)).to_i
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

def status(idx,seed,count,action)
  p1 = " reduction: #{idx} ".center(20)
  p2 = " seed: #{seed}/#{count} ".center(20)
  p3 = " #{action} ".center(20)
  "\r ** #{p1} ** #{p2} ** #{p3} **".center(80)
end


LETTER = ''
WIDTH = 80
PAD = 4
BAR = WIDTH - 2*PAD

def stats
  x = Math.log(@stats[:seed],2) / Math.log(@stats[:count].to_i,2)
  x = 0 unless x.finite?
  percentage = (x * 100).round
  <<-eos
reduction: #{@stats[:index]}
status: #{@stats[:doing]}
seeds: #{@stats[:seed]}/#{@stats[:count]} (#{percentage}%)

#{" " * PAD}#{LETTER * (BAR*x)}#{"_" * (BAR*(1-x))}

  eos
end

def display
  s = stats
  if @hit
    print "\r"
    print "\e[A\e[K" * s.lines.count
  end
  print s
  @hit = true
end

begin

  puts version.bold
  error "single input file required" unless ARGV.count == 1
  error "input file does not exist" unless File.exist?(ARGV.first)
  error "must specify a query method" unless @query
  error "must specify a reduce method" unless @reduce
  warn "termination is not guaranteed without seed counting" unless @count
  error "output directory #{@dir} already exists" if File.exist?(@dir)
  @input = ARGV.first

  @gen = Generator.new(
    Naming.new(@dir,@input),
    @query, @reduce, @count, @efile, @eseed
  )

  @stats = {
    index: 0,
    seed: 0,
    count: "?",
    doing: :querying,
  }

  display
  t = Time.now
  @gen.query(0)
  @stats[:ref_time] = Time.now - t

  1.step do |index|
    @stats[:index] = index
    @stats[:doing] = :counting
    display
    @stats[:count] = @gen.count(index-1)

    break unless current = current.upto(@stats[:count]).find do |seed|
      @stats[:seed] = seed
      @stats[:doing] = :reducing
      display
      @gen.reduce(index,seed)

      @stats[:doing] = :querying
      display
      @gen.query(index)
    end
  end
  puts
  puts "Done whittling."

rescue Interrupt

ensure

end
