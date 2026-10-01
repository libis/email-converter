# frozen_string_literal: true

require_relative 'html_templates'

require 'base64'
require 'cgi'
require 'time'
require 'fileutils'
require 'pathname'

require 'pdfkit'

module Libis
  module Format
    module Converter
      class EmailConverter

        @@registered_formats = {}

        def self.register(input_format, output_format)
          @@registered_formats ||= {}
          @@registered_formats[input_format.to_sym] ||= {}
          @@registered_formats[input_format.to_sym][output_format.to_sym] = self
        end

        def self.convert(source, **options)
          options[:input_format] ||= File.extname(source).downcase.delete_prefix('.').to_sym
          options[:output_dir] ||= Dir.pwd
          options[:output_format] ||= :html

          converter_class = @@registered_formats&.dig(options[:input_format].to_sym, options[:output_format].to_sym)
          raise "No converter registered for input format '#{options[:input_format]}' and output format '#{options[:output_format]}'" unless converter_class

          target = File.join(options[:output_dir], "#{File.basename(source, '.*')}.#{options[:output_format]}")
          converter = converter_class.new(source, target, **options)
          converter.convert
        end

        def initialize(source, target, **options)
          @source = source
          @target = target
          @options = options
        end

        def convert
          process_email
        end

        def process_email

          # Preliminary checks
          @warnings = []

          if @options[:output_format] == :pdf

            # PDF creation options
            pdf_options = {
              page_size: 'A4',
              margin_top: '10mm',
              margin_bottom: '10mm',
              margin_left: '10mm',
              margin_right: '10mm',
              dpi: 300
            }.merge(@options.fetch(:pdf_options, {}))

            # PDFKit configuration
            PDFKit.configure do |config|
              config.default_options = pdf_options
              config.wkhtmltopdf = @options[:wkhtmltopdf_path] if @options[:wkhtmltopdf_path]
              config.root_url = @options.fetch(:wkhtmltopdf_root_url, 'http://localhost')
              config.verbose = @options.fetch(:wkhtmltopdf_verbose, false)
            end
          end

          # Check if source file exists
          raise "File #{@source} does not exist" unless File.exist?(@source)

          # Open the email
          email = open_email(@source)

          # Convert the email message to PDF
          result = convert_email(email, @target, root_msg: true)

          # Close email message
          close_email(email)

          result
        end

        protected

        def convert_email(msg, target, root_msg: false)
          # Make sure the target directory exists
          outdir = File.dirname(target)
          FileUtils.mkdir_p(outdir)

          # Process the message body
          # ------------------------
          body = get_body(msg)

          # Process headers
          # ---------------
          headers, headers_html = get_headers(msg)

          # Add header section to the HTML body
          body = add_headers_to_body(body, headers_html)

          # Embed inline images
          # -------------------
          attachments = msg.attachments
          used_files = embed_inline_attachments(body, attachments)

          # Save other attachments
          # ----------------------
          attachments_dir = "#{target}.attachments"

          files = save_attachments(attachments, attachments_dir, used_files)

          # Add attachment section to the HTML body
          body = add_attachments_to_body(body, files, attachments_dir)

          case @options[:output_format]
          when :html
            # Create HTML file
            File.open(target, 'wb') { |f| f.write(body) }
          when :pdf
            # Create PDF
            write_target_file(body, get_subject(msg), target)
          else
            raise "Unsupported output format: #{@options[:output_format]}"
          end

          files = [target] + files if File.exist?(target)

          if root_msg
            p = Pathname(File.dirname(files.first))
            files.drop(1).each do |f|
              (headers[:attachments] ||= []) << Pathname.new(f).relative_path_from(p).to_s
            end
          end

          {
            command: { status: 0 },
            files: files,
            headers: headers,
            warnings: @warnings
          }
        rescue StandardError => e
          raise unless root_msg

          close_email(msg) if msg
          {
            command: { status: -1 },
            files: [],
            headers: {},
            errors: [
              {
                error: e.message,
                error_class: e.class.name,
                error_trace: e.backtrace
              }
            ],
            warnings: @warnings
          }
        end

        def get_body(msg)
          body = get_body_html(msg)

          body = HTML_BODY_TEMPLATE % body unless /<body[^>]*>/i.match?(body)
          body = HTML_DOCTYPE_TEMPLATE % body unless /<!DOCTYPE html/i.match?(body)
          body.sub!(%r{<title>title</title>}, "<title>#{get_subject(msg)}</title>")

          body
        end

        def add_headers_to_body(body, headers_html)
          encoding = body.encoding
          return body if headers_html.empty?

          b = body.downcase

          # Insert header block styles
          if b.include?('</head>')
            # if head exists, append the style block
            body.gsub!(%r{</head>}i, "#{HEADER_STYLE}</head>")
          elsif b.include?('<head/>')
            # empty head, replace with the style block
            body.gsub!(%r{<head/>}i, "<head>#{HEADER_STYLE}</head>")
          else
            # otherwise insert a head section before the body tag
            body.gsub!(/<body/i, "<head>#{HEADER_STYLE}</head><body")
          end
          # Add the headers html table as first element in the body section
          body.gsub!(/<body[^>]*>/i) { |m| "#{m}#{HEADER_TABLE_TEMPLATE % headers_html.encode(encoding)}" }
          body
        end

        def hdr_html(key, value)
          if key.is_a?(String) && value.is_a?(String) && !value.empty?
            return format(HEADER_FIELD_TEMPLATE, key,
                          CGI.escapeHTML(value))
          end

          ''
        end

        def embed_inline_attachments(body, attachments)
          used_files = []

          # First process plaintext cid entries
          body.gsub!(IMG_CID_PLAIN_REGEX) do |_match|
            data = get_inline_attachment_data(attachments, ::Regexp.last_match(1))
            if data
              used_files << ::Regexp.last_match(1)
              "<img src=\"data:#{data[:mime_type]};base64,#{data[:base64]}\"/>"
            else
              '<img src=""/>'
            end
          end

          # Then process HTML img tags with CID entries
          body.gsub!(IMG_CID_HTML_REGEX) do |_match|
            data = get_inline_attachment_data(attachments, ::Regexp.last_match(1))
            if data
              used_files << ::Regexp.last_match(1)
              "data:#{data[:mime_type]};base64,#{data[:base64]}"
            else
              ''
            end
          end

          used_files
        end

        def save_attachments(attachments, outdir, used_files)
          files = []

          digits = ((attachments.count + 1) / 10) + 1
          i = 1

          get_attachments(attachments, used_files).each do |attachment|
            prefix = "#{format('%0*d', digits, i)}-"

            info = get_attachment_info(attachment)

            if info[:embedded_msg]
              sub_msg = info[:embedded_msg]
              file = File.join(outdir, "#{prefix}#{info[:filename].tr('/', '_')}.msg.#{@options[:output_format]}")

              result = convert_email(sub_msg, file, root_msg: false)

              if (e = result[:error])
                raise e
              end

              files += result[:files]
            elsif info[:data]
              file = File.join(outdir, "#{prefix}#{info[:filename].tr('/', '_')}")
              FileUtils.mkdir_p(File.dirname(file))
              File.open(file, 'wb') { |f| f.write(info[:data]) }
              files << file
            else
              @warnings << "Attachment #{info[:filename]} cannot be extracted"
              next
            end

            i += 1
          end
          files
        end

        def add_attachments_to_body(body, files, attachments_dir)
          return body if files.empty?

          b = body.downcase

          # Insert attachment block styles
          if b.include?('</head>')
            # if head exists, append the style block
            body.gsub!(%r{</head>}i, "#{ATTACHMENT_STYLE}</head>")
          elsif b.include?('<head/>')
            # empty head, replace with the style block
            body.gsub!(%r{<head/>}i, "<head>#{ATTACHMENT_STYLE}</head>")
          else
            # otherwise insert a head section before the body tag
            body.gsub!(/<body/i, "<head>#{ATTACHMENT_STYLE}</head><body")
          end

          # Filter files to only include those that are in the attachments directory
          # and map them to relative paths from the attachments directory
          items = files.filter_map do |f|
            Pathname.new(f).relative_path_from(Pathname.new(attachments_dir)).to_s if File.dirname(f) == attachments_dir
          end

          # Create the attachment item HTML
          items = items.map do |f|
            format(ATTACHMENT_ITEM_TEMPLATE, f, File.basename(f))
          end.join("\n")

          # Create the attachment list HTML
          attachments_html = ATTACHMENT_LIST_TEMPLATE % items

          # make sure the attachments_html is encoded in the same encoding as the body
          attachments_html = attachments_html.encode(body.encoding)

          # Add the attachments html list after the headers
          # if there are no headers, then add it at the beginning of the body section
          body.sub!(%r{<div class="header-table">.*?</div>}im) { |m| "#{m}#{attachments_html}" } ||
            body.gsub!(/<body[^>]*>/i) { |m| "#{m}#{attachments_html}" }

          body
        end

        def get_attachments(attachments, used_files)
          get_file_attachments(attachments, used_files) + get_mail_attachments(attachments)
        end

        def write_target_file(body, title, target)
          kit = PDFKit.new(body, title: title || 'message')
          pdf = kit.to_pdf
          File.open(target, 'wb') { |f| f.write(pdf) }
        end

        # ---------------------------------------
        # Methods to be implemented by subclasses
        # ---------------------------------------
        def open_email(_source)
          raise NotImplementedError, 'Subclasses must implement the open_email method'
        end

        def close_email(_email)
          raise NotImplementedError, 'Subclasses must implement the close_email method'
        end

        def get_body_html(_msg)
          raise NotImplementedError, 'Subclasses must implement the get_body_html method'
        end

        def get_subject(_msg)
          raise NotImplementedError, 'Subclasses must implement the get_subject method'
        end

        def get_headers(_msg)
          raise NotImplementedError, 'Subclasses must implement the get_headers method'
        end

        def get_inline_attachment_data(_attachments, _cid)
          raise NotImplementedError, 'Subclasses must implement the get_inline_attachment_data method'
        end

        def get_file_attachments(_attachments, _used_files)
          raise NotImplementedError, 'Subclasses must implement the get_file_attachments method'
        end

        def get_mail_attachments(_attachments)
          raise NotImplementedError, 'Subclasses must implement the get_mail_attachments method'
        end

        def get_attachment_info(_attachment)
          raise NotImplementedError, 'Subclasses must implement the get_attachment_info method'
        end
      end
    end
  end
end
