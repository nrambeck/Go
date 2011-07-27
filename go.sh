#!/usr/bin/env ruby

# == Synopsis 
#   go is a script for creating and executing unix commands using shortcuts
#
# == Examples
#   This command might ssh into a development server
#     go devserver
#   Add a new shortcut, you will be prompted for the command
#     go -a devserver
#   Remove an existing shortcut
#     go -d devserver
#   List all available shortcuts
#     go -l
#
# == Usage 
#   go [options] shortcut
#
#   For help use: go -h
#
# == Options
#   -h, --help          Displays help message
#   -v, --version       Display the version, then exit
#   -q, --quiet         Output as little as possible, overrides verbose
#   -V, --verbose       Verbose output
#   -a, --add           Add a new shell command
#   -d, --remove        Remove an existing shell command shortcut
#   -l, --list          List all shell command shortcuts
#
# == Author
#   Nathan Rambeck
#   http://nathan.rambeck.org
#
# == Copyright
#   Copyright (c) 2011 Nathan Rambeck. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php



require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
require 'date'
require "yaml"


class App
  VERSION = '0.0.1'
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
    @options.add = false
    @options.remove = false
    @options.list = false
  end

  # Parse options, check arguments, then process the command
  def run
        
    if parsed_options? && arguments_valid? 
      
      puts "Start at #{DateTime.now}\n\n" if @options.verbose
      
      output_options if @options.verbose # [Optional]
            
      process_arguments            
      process_command
      
      puts "\nFinished at #{DateTime.now}" if @options.verbose
      
    else
      output_usage
    end
      
  end
  
  protected
  
    def parsed_options?
      
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version')    { output_version ; exit 0 }
      opts.on('-h', '--help')       { output_help }
      opts.on('-V', '--verbose')    { @options.verbose = true }  
      opts.on('-q', '--quiet')      { @options.quiet = true }
      opts.on('-a', '--add')        { @options.add = true }
      opts.on('-d', '--remove')     { @options.remove = true }
      opts.on('-l', '--list')       { @options.list = true }
            
      opts.parse!(@arguments) rescue return false
      
      process_options
      true      
    end

    # Performs post-parse processing on options
    def process_options
      @options.verbose = false if @options.quiet
    end
    
    def output_options
      puts "Options:\n"
      
      @options.marshal_dump.each do |name, val|        
        puts "  #{name} = #{val}"
      end
    end

    # True if required arguments were provided
    def arguments_valid?
      true if @arguments.length == 1 || @options.list == true
    end
    
    # Setup the arguments
    def process_arguments
      # TO DO - place in local vars, etc
    end
    
    def output_help
      output_version
      RDoc::usage() #exits app
    end
    
    def output_usage
      RDoc::usage('usage') # gets usage from comments above
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    def process_command
      go = Go.new
      
      if @options.add == true
        go.add(@arguments.first)
      elsif @options.remove == true
        go.remove(@arguments.first)
      elsif @options.list == true
        go.list()
      else
        if go.bookmarks.length == 0
          puts "You're bookmarks list is empty"
          return
        end
        matches = go.find(@arguments.first)
        
        if matches.length == 0
          puts "No shortcuts found"
          return
        end
        if matches.length == 1
          go.execute(matches.first)
        else
          go.list_matches(matches)
          print "Select #: "
          selection = STDIN.gets.chomp.to_i
          selection = selection - 1
          if selection > 0 && matches[selection]
            exec matches[selection]["cmd"]
          end
        end
        
      end
      
      #process_standard_input # [Optional]
    end

    def process_standard_input
      input = @stdin.read      
    end
end


class Go
  
  YAML_LOCATION = File.expand_path('~/.go/go.yaml')
  
  def initialize
    # check for yaml file
    if not File.exists?(YAML_LOCATION)
      # create an empty one if it doesn't exist
      if not FileTest.directory?(YAML_LOCATION)
        Dir.mkdir(File.dirname(YAML_LOCATION))
      end
      
      File.open(YAML_LOCATION, 'w') {|f| f.write('')}
    end
    load_bookmarks()
  end
  
  def execute(item)
    puts item["cmd"]
    exec item["cmd"]
  end
  
  def load_bookmarks
    @bookmarks = {}
    h = YAML.load_file(YAML_LOCATION)
    if h
      @bookmarks = @bookmarks.merge(h)
    end
  end
  
  def bookmarks
    return @bookmarks
  end

  def find(shortcut)
    # grab a list of favorites
    items = @bookmarks
    if items.has_key?(shortcut)
      return [{"shortcut" => shortcut, "cmd" => items[shortcut]}]
    else
      matches = []
      i = 0
      maxlen_shortcut = 0
      rx = Regexp.new("(.*)" + shortcut + "(.*)", Regexp::IGNORECASE)
      items.each do |k,v|
        if (k.match(rx) || v.match(rx))
          # build a list possible matches
          matches[i] = {"shortcut" => k, "cmd" => v}
          if (k.length > maxlen_shortcut)
            maxlen_shortcut = k.length
          end
          i = i + 1
       end
      end
      return matches
    end
  end
  
  def list_matches(matches)
    maxlen_shortcut = 4
    matches.each do |m|
      if m["shortcut"].length > maxlen_shortcut
        maxlen_shortcut = m["shortcut"].length
      end
    end
    matches.each_with_index do |m,i|
      num = i + 1
      sel_num = num.to_s + "."
      puts sel_num.ljust(4) + m["shortcut"].ljust(maxlen_shortcut) + " " + m["cmd"]
    end
  end
  
  def list
    matches = []
    i = 0
    @bookmarks.each do |k,v|
      matches[i] = {"shortcut" => k, "cmd" => v}
      i = i + 1
    end
    list_matches(matches)
  end
  
  def add(shortcut)
    y = @bookmarks
    print "Enter the command to add: "
    cmd = STDIN.gets.chomp
    if cmd.length > 0
      y = y.merge({shortcut => cmd})
      f = File.open(YAML_LOCATION, 'w')
      f.write(YAML.dump(y))
      puts "Successfully added the shortcut \"#{shortcut}\" to the command \"#{cmd}\""
    else
      puts "No shortcut was added"
    end
  end
  
  def remove(shortcut)
    # find item with that shortcut
    if @bookmarks.has_key?(shortcut)
      # confirm removal
      print "Remove shortcut \"#{shortcut}\" (y/n)? "
      confirm = STDIN.gets.chomp
      if confirm == 'y'
        # remove hash item with shortcut key
        @bookmarks.delete(shortcut)
        f = File.open(YAML_LOCATION, 'w')
        f.write(YAML.dump(@bookmarks))
     end
    end
    
  end
end


# Create and run the application
app = App.new(ARGV, STDIN)
app.run
