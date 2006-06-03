#!/usr/local/bin/ruby -ws

require "tempfile"

$a = false unless defined? $a

# OO Version of zengraph, which allows for a completely customizable
# parsing and graphing system. The first major subsystem is responsible
# for parsing arbitrary text into a deep data structure whose basic shape
# is:
# 
# Data->{date}{xN} = Y.
# 
# where:
# 
# date is the X unit, in YYYY-MM-DD format.
# xN is some identifier specifing WHICH X we are graphing.
# Y is any value for xN on date.
# 
# The second subsystem translates some or all of the data into a 
# set of datafiles for gnuplot, creates the output, and optionally 
# saves or displays the graph.
# 
# Things immediatly needed:
# 
# 1) Datastructure definition.
# 2) Basic structure of the two subsystems.
# 3) Customizablity of parser.
# 4) Some basic options to specify end result.
# 
# Secondary concerns:
# 
# 1) Complete customizability of every field in graph.
# 2) Ability to redifine what the second subsystem does altogether.
# 3) Removing gnuplot as a requirement and using something native (GD?).
# 4) Plug-in via cmd-line vs subclassing.

class GraphData

  attr_reader :data

  def initialize
    @data = {}
  end # initialize

  def [](date, label)
    tmp = @data[date]

    return tmp.nil? ? nil : tmp[label]
  end

  def has_keys?(date, label)
    return @data.has_key?(date) && @data[date].has_key?(label)
  end

  def []=(date, label, value)

    @data[date] = {} if @data[date].nil?
    @data[date][label] = value
  end

  def titles 

    titles = []

    for date in @data.keys.sort
      for key in @data[date].keys.sort
	titles.push key unless titles.include? key
      end
    end

    return titles
  end

  def dates
    return @data.keys
  end

end # GraphData

class ZenGraph

  def initialize
    @data = GraphData.new
    @title = 'No Title'
    @generated = false
  end

  def []=(date, label, value)
    @data[date, label] = value
  end

  def process_files(files)
    files.each {
      | file |

      process_file(file)
    }
  end

  def save(file)
    generate_gnuplot unless @generated

    `cp temp.#{$$}.png #{file}`
    File.unlink "temp.#{$$}.png"
  end

  def view
    generate_gnuplot unless @generated

    `xv temp.#{$$}.png`
  end

  protected

  def process_file(file)
    IO.foreach(file) {
      | line |
      process_line(line)
    }
  end

  def initialize_file(file)
    # override in subclass if you want any file-level inits
  end

  def process_line(line)
    # override in subclass to process a line of the file.
  end

  def generate_gnuplot

    out = Tempfile.open("zengraph_dat.")

    titles = @data.titles.sort
    for title in titles
      out.printf "%12s%12s\n", '#Day', title;

      for date in @data.dates.sort { |a,b| a <=> b }
	if @data.has_keys?(date, title) then
	  out.printf "%-12s%12.2f\n", date, @data[date, title]
	end
      end

      out.puts
      out.puts
    end

    path = out.path
    out.close

    out = Tempfile.open("zengraph_dem.")

    # TODO these should all be customizable
    out.puts "set terminal png small"
    out.puts "set output 'temp.#{$$}.png'"
    out.puts "set timefmt '%Y-%m-%d'"
    out.puts "set xdata time"
    out.puts "set ylabel 'Count'"
    out.puts "set xlabel 'Date'"
    out.puts "set format x \"%s\""
    out.puts "set format x \"%m-%d\\n%Y\""
    out.puts "set title \"#{@title}\""
    out.print "plot ";

    # I can't stand cyan or yellow on a white background
    # echo "set terminal png; test" | gnuplot > test.png
    lt = ((1..33).to_a - [5, 7, 9, 19]) * 5

    titles.sort.each_with_index do |title,i|
       out.print ", " if i > 0
       out.print "'#{path}' index #{i} using 1:2 t '#{title}' with linespoints lt #{lt[i]} "
    end

    out.close

    `gnuplot #{out.path}`
    @generated = true
  end
end # ZenGraph

if $0 == __FILE__

  class MyZenGraph < ZenGraph

    def process_line(line)
      # if (line =~ /(\d\d\d\d-\d\d-\d\d):\s*(\w+)\s+(\d+)/)
      if (line =~ /(\d\d\d\d-\d\d-\d\d):\s*(\w+)\s+([\d\.]+)/)
	@data[$1, $2] = $3
      end
    end

  end # MyZenGraph

  graph = MyZenGraph.new()
  graph.process_files("data.txt")
  graph.save("blah.png")

end
