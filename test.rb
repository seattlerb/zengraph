#!/usr/local/bin/ruby -w

ARGV.each {
  | file |
  puts file
}

$<.each { |l| puts l }
