#!/usr/local/bin/ruby

require "tempfile"

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

  def initialize
    @data = {}
  end # initialize

  def [](date, label)
    tmp = @data[date]

    return tmp.nil? ? nil : tmp[label]
  end

  def []=(date, label, value)

    @data[date] = {} if @data[date].nil?
    @data[date][label] = value
  end

  def titles 

    titles = []
    for date in @data.keys.sort!
      for key in @data[date].keys.sort!
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

  def process_files(files)
    files.each {
      | file |

      process_file(file)
    }

  end

  def save(file)
    generate_gnuplot unless @generated

    # `cp temp.$$.png #{file}`

  end

  def view
    generate_gnuplot unless @generated

    # `xv temp.$$.png`

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

    titles = @data.titles.sort

    headers = titles.dup
    headers.unshift('#Day')

    out = Tempfile.open("zengraph_dat.")

    for title in headers
      out.printf "%-12s ", title;
    end
    out.puts

    for date in @data.dates.sort! { |a,b| a <=> b }
      out.printf "%-12s ", date
      for tag in titles
	n =  @data[date, tag] || 0
	out.printf "%-12d ", n
      end
      out.puts
    end

    path = out.path
    out.close

    `cp #{path} t.dat`

    out = Tempfile.open("zengraph_dem.")

    # TODO these should all be customizable
    out.print "set terminal png small color\n";
    out.print "set output 'temp.png'\n";
    out.print "set timefmt '%Y-%m-%d'\n";
    out.print "set xdata time\n";
    out.print "set ylabel 'Count'\n";
    out.print "set xlabel 'Date'\n";
    out.print "set format x \"%m-%d\\n%Y\"\n";
    out.print "set title \"#{@title}\"\n";
    out.print "plot ";

    # 1 red
    # 2 lime green
    # 3 blue
    # 4 cyan
    # 5 magenta
    # 6 yellow
    # 7 brownish
    # 8 forest green
    # 9 navy blue

    # I can't stand cyan or yellow on a white background
    lt = [ 1, 2, 3, 5, 7, 8, 9 ] * 5

    i = 1
    for title in titles
      out.print ", " if i > 1
      i = i + 1
      out.print "'#{path}' using 1:#{i} t '#{title}' with lines lt #{lt[i-2]} "
    end

    out.close
    `cp #{out.path} t.dem`

    `/usr/local/bin/gnuplot #{out.path}`
    @generated = true

  end
  
end # ZenGraph

if $0 == __FILE__

  class MyZenGraph < ZenGraph

    def process_line(line)
      #if (line =~ /(\d\d\d\d-\d\d-\d\d):\s*(\w+)\s+([\d\.]+)/)
      if (line =~ /(\d\d\d\d-\d\d-\d\d):\s*(\w+)\s+(\d+)/)
	@data[$1, $2] = $3
      end
    end

  end # MyZenGraph

  graph = MyZenGraph.new()
  graph.process_files("data.txt")
  graph.save("blah.png")

end
