#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/libis/format/converter/eml_converter'
require_relative '../lib/libis/format/converter/msg_converter'

require 'optparse'
require 'json'

@input_format = nil
@output_format = :html
@output_dir = nil
@recursive = false
@quiet = false

opts = OptionParser.new

opts.banner = <<~BANNER
  Usage: email_converter [options] <source> ...

  if <source> is a directory, the recursive option can be used

  Options:
BANNER

opts.on('-h', '--help', 'Display this help message') do
  puts opts
  exit
end

opts.on('-q', '--quiet', 'Suppress output messages') do
  @quiet = true
end

opts.on('-i', '--input FORMAT', %w[eml msg],
        'Specify the input format (eml or msg, default is derived from the file extension)') do |format|
  @input_format = format.to_sym if format
end

opts.on('-o', '--output FORMAT', %w[html pdf],
        'Specify the output format (pdf or html, default: html)') do |format|
  @output_format = format.to_sym if format
end

opts.on('-d', '--outdir DIR', 'Specify the output directory (default: current directory)') do |dir|
  @output_dir = dir
end

opts.on('-v', '--version', 'Display the version') do
  require_relative '../lib/libis/format/version'
  puts Libis::Format::VERSION
  exit
end

opts.on('-r', '--recursive', 'Enable recursive processing of directories') do
  @recursive = true
end
opts.parse!

if ARGV.empty?
  puts opts.banner
  puts opts
  exit
end

# rubocop:disable all
def process_file(file)
  options = {
    input_format: @input_format,
    output_format: @output_format,
    output_dir: @output_dir || Dir.pwd
  }.compact
  result = Libis::Format::Converter::EmailConverter.convert(file, **options)

  if result&.fetch(:errors, []).any?
    puts "Error converting '#{file}' to #{@output_format.to_s.upcase}:" unless @quiet
    result&.fetch(:errors, []).each { |error| puts error[:error] } unless @quiet
    File.write(File.join(@output_dir, "#{File.basename(file, '.*')}.json"), JSON.pretty_generate(result.compact))
  else
    puts "Successfully converted '#{file}' to #{@output_format.to_s.upcase}" unless @quiet
    File.write(File.join(@output_dir, "#{File.basename(file, '.*')}.json"), JSON.pretty_generate(result.compact))
  end
end
# rubocop:enable all

def process_directory(dir)
  Dir.glob("#{dir}/*").each do |file|
    if File.directory?(file) && @recursive
      process_directory(file)
    elsif File.file?(file)
      process_file(file)
    end
  end
end

ARGV.each do |file|
  if File.directory?(file)
    if @recursive
      Dir.glob("#{file}/**/*").each do |f|
        process_file(f) if File.file?(f)
      end
    else
      process_directory(file)
    end
  else
    process_file(file)
  end
end
