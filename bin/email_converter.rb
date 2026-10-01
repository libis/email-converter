#!/usr/bin/env ruby
# frozen_string_literal: true

# Email converter
# Copyright (C) 2026 LIBIS, KU Leuven
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Kris Dekeyser <kris.dekeyser@kuleuven.be>

require_relative '../lib/libis/format/converter/eml_converter'
require_relative '../lib/libis/format/converter/msg_converter'

require 'optparse'
require 'json'

@options = {
  input_format: nil,
  output_format: :html,
  output_dir: Dir.pwd,
  recursive: false,
  quiet: false
}

opts = OptionParser.new

opts.banner = <<~BANNER
  Usage: email_converter [options] <source> ...

  if <source> is a directory, the recursive option can be used

  The default pdf options are:
  #{Libis::Format::Converter::EmailConverter::DEFAULT_PDF_OPTIONS.map { |k, v| "  #{k}=#{v}" }.join("\n")}

  Options:
BANNER

opts.accept(:hash) do |hash_string|
  hash = {}
  hash_string.strip.split(',').map(&:strip).each do |pair|
    key, value = pair.split('=', 2)
    hash[key.strip.to_sym] = value.strip
  end
  hash
end

opts.on('-h', '--help', 'Display this help message') do
  puts opts
  exit
end

opts.on('-q', '--quiet', 'Suppress output messages') do
  @options[:quiet] = true
end

opts.on('-i', '--input FORMAT', %w[eml msg],
        'Specify the input format (eml or msg, default is derived from the file extension)') do |format|
  @options[:input_format] = format.to_sym if format
end

opts.on('-o', '--output FORMAT', %w[html pdf],
        'Specify the output format (pdf or html, default: html)') do |format|
  @options[:output_format] = format.to_sym if format
end

opts.on('-d', '--outdir DIR', 'Specify the output directory (default: current directory)') do |dir|
  @options[:output_dir] = dir
end

opts.on('-v', '--version', 'Display the version') do
  require_relative '../lib/libis/format/version'
  puts Libis::Format::VERSION
  exit
end

opts.on('-r', '--recursive', 'Enable recursive processing of directories') do
  @options[:recursive] = true
end

opts.on('--no-recursive-convert', 'Disable recursive conversion of embedded/attached emails') do
  @options[:no_recursive_convert] = true
end

opts.on('--export-converted', 'Enable exporting of converted attached emails') do
  @options[:export_converted] = true
end

opts.on('--wkhtmltopdf_path PATH', 'Specify the path to the wkhtmltopdf executable') do |path|
  @options[:wkhtmltopdf_path] = path
end

opts.on('--wkhtmltopdf_verbose', 'Enable verbose output for wkhtmltopdf') do
  @options[:wkhtmltopdf_verbose] = true
end

opts.on('--pdf_options OPTIONS', "Specify additional options for wkhtmltopdf (in JSON format)", :hash) do |options|
  @options[:pdf_options] = options
end

opts.parse!

if ARGV.empty?
  puts opts unless @options[:quiet]
  exit
end

# rubocop:disable all
def process_file(file)
  options = @options.dup.compact

  result = Libis::Format::Converter::EmailConverter.convert(file, **options)

  if result&.fetch(:errors, []).any?
    puts "Error converting '#{file}' to #{@options[:output_format].to_s.upcase}:" unless @options[:quiet]
    result&.fetch(:errors, []).each { |error| puts error[:error] } unless @options[:quiet]
    File.write(File.join(options[:output_dir], "#{File.basename(file)}.json"), JSON.pretty_generate(result.compact))
  else
    puts "Successfully converted '#{file}' to #{@options[:output_format].to_s.upcase}" unless @options[:quiet]
    File.write(File.join(options[:output_dir], "#{File.basename(file)}.json"), JSON.pretty_generate(result.compact))
  end
end
# rubocop:enable all

def process_directory(dir)
  Dir.glob("#{dir}/*").each do |file|
    if File.directory?(file) && @options[:recursive]
      process_directory(file)
    elsif File.file?(file)
      process_file(file)
    end
  end
end

ARGV.each do |file|
  if File.directory?(file)
    if @options[:recursive]
      # Process all files recursively in the directory and its subdirectories
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
