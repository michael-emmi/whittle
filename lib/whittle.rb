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

def file_size(file)
  File.read(file).scan(/\n/).count
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
  def final
    File.join(@directory,"#{@basename}.whittled#{@extname}")
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
    if FileUtils.identical?(@naming.result(0), @naming.result(index))
      FileUtils.cp(@naming.reduction(index),@naming.final)
      true
    else
      false
    end
  end
  def reduce(index, seed)
    command = @reduce.
      gsub(/#{@file_expr}/, @naming.reduction(index-1)).
      gsub(/#{@seed_expr}/, seed.to_s)
    run(command, @naming.reduction(index))
    file_size(@naming.reduction(index))
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
  opts.on("-o", "--output-dir", "Output directory") do |d|
    @dir = d
  end
  opts.separator ""
end.parse!

class Stats

  LETTER = '#'
  WIDTH = 70

  def initialize
    @timings = {}
    @data = {}
  end

  def to_s

    if @timings[:query]
      qtimes = @timings[:query].each_with_index.
        select{|_,i| @data[:query][i]}.map{|t,_| t}
    end
    qresults = @data[:query]

    itime = qtimes ? "#{qtimes.first.round(2)}s" : ""
    atime = qtimes ? "#{(qtimes.reduce(:+) / qtimes.count).round(2)}s" : ""
    ctime = qtimes ? "#{qtimes.last.round(2)}s" : ""

    pqueries = qresults ? qresults.drop(1).select{|res| res}.count.to_s : ""
    fqueries = qresults ? qresults.drop(1).select{|res| !res}.count.to_s : ""

    if @data[:reduce]
      rresults = @data[:reduce].each_with_index.
        select{|_,i| @data[:query][i+1]}.map{|t,_| t}
    end

    isize = @data[:size]
    csize = rresults.last unless rresults.nil? || rresults.empty?
    pcred = "(#{(100.0 * csize / isize).round}%)" if csize

    status = @data[:status]
    index = (@data[:index] || 1) - 1
    count = @data[:count].last if @data[:count]
    seed = @data[:seed]

    progress =
      Math.sqrt(seed.to_f + index + 1) / Math.sqrt(count.to_f + index + 1)
    progress = 0 unless progress.finite? && @data[:count]
    percentage = (progress * 100).round

    rtime = (Time.now - @data[:start_time]).round
    seconds = rtime % 60
    minutes = rtime / 60 % 60
    hours = rtime / 60 / 60
    time = "#{hours}h #{minutes}m #{seconds}s"

    str = <<-eos

  queries                             reductions
  -------                             ----------
  initial time: #{itime.ljust(18)}    valid reductions: #{index}
  average time: #{atime.ljust(18)}    initial size: #{isize}
  current time: #{ctime.ljust(18)}    current size: #{csize} #{pcred}

  Nº passed: #{pqueries.ljust(21)}    current seed Nº: #{seed}
  Nº failed: #{fqueries.ljust(21)}    available seeds: #{count}

  #{LETTER * (WIDTH*progress)}#{"_" * (WIDTH*(1-progress))} (#{percentage}%)
  (approximate progress)              running time: #{time}
    eos

    case status
    when :query
      str.sub('queries',"QUERIES".bold).sub('-' * 7, '=' * 7)
    when :reduce
      str.sub('reductions',"REDUCTIONS".bold).sub('-' * 10, '=' * 10)
    else
      str.sub('reductions',"(COUNTING)".bold).sub('-' * 10, '=' * 10)
    end
  end

  def display
    s = to_s
    if @hit
      print "\r"
      print "\e[A\e[K" * s.lines.count
    end
    print s
    @hit = true
  end

  def watch(status, extras = {})
    @data[:status] = status
    @data.merge!(extras)
    display
    t = Time.now
    res = yield if block_given?
    @timings[status] ||= []
    @data[status] ||= []
    @timings[status] << (Time.now - t)
    @data[status] << res
    display
    res
  end

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

  @naming = Naming.new(@dir,@input)
  @gen = Generator.new(@naming, @query, @reduce, @count, @efile, @eseed)
  @stats = Stats.new

  @stats.watch(:query, size: file_size(@input), start_time: Time.now) {@gen.query(0)}
  current = 0

  1.step do |index|
    count = @stats.watch(:count, index: index) {@gen.count(index-1)}
    break unless current = current.upto(count).find do |seed|
      @stats.watch(:reduce, seed: seed) {@gen.reduce(index,seed)}
      @stats.watch(:query) {@gen.query(index)}
    end
  end

rescue Interrupt

ensure
  if @naming && File.exist?(@naming.final)
    puts
    puts "Result written to #{@naming.final}"
  end
end
