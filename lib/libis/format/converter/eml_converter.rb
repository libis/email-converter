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

require_relative 'email_converter'

require 'mail'
require 'word_wrap'

module Libis
  module Format
    module Converter
      class EmlConverter < EmailConverter
        register :eml, :html
        register :eml, :pdf

        protected

        def open_email(source)
          eml = File.read(source)
          begin
            msg = Mail.new(eml)
          rescue StandardError => e
            eml.force_encoding('ASCII-8BIT')
            msg = Mail.new(eml)
            @warnings << "Failed to parse message with default encoding, forced ASCII-8BIT: #{e.message}"
          end
          msg
        rescue StandardError => e
          raise "Failed to open message: #{e.message}"
        end

        def close_email(_msg)
          true
        end

        def get_body_html(msg)
          # Get the encoding

          if !msg.multipart?
            HTML_WRAPPER_TEMPLATE % WordWrap.ww(msg.decoded, 120, false)

          elsif msg.html_part
            body = msg.html_part.body.decoded

            # if the encoding is not UTF-8, then the HTML may contain metadata that specifies the encoding
            # the browser will use that metadata to render the HTML correctly, so we should not force it to UTF-8
            encoding = body.scan(/<\?xml\s[^?>]*encoding="([^"]*)"[^?>]*\?>/).flatten.first
            encoding ||= body.scan(/<meta\s+[^>]*charset=["']?([^"'>\s]+)["']?[^>]*>/).flatten.first
            encoding ||= msg.html_part.charset
            encoding ||= msg.content_type_parameters['charset'] || msg.charset || 'UTF-8'

            body.force_encoding(encoding) unless encoding.casecmp(body.encoding.name).zero?

            body
          elsif msg.text_part
            HTML_WRAPPER_TEMPLATE % msg.text_part.decoded

          else
            HTML_WRAPPER_TEMPLATE % ''

          end
        end

        def get_subject(msg)
          msg.subject || 'No Subject'
        end

        def get_headers(msg)
          headers = {}
          html = ''

          field_list = msg.header_fields

          %w[From To Cc Subject Date].each do |key|
            value = find_hdr(field_list, key)
            next unless value

            if value.is_a? Time
              begin
                headers[key.downcase.to_sym] = value.iso8601
                html += hdr_html(key, value.rfc2822)
              rescue StandardError => e
                logger.warn "Failed to parse date header '#{value}': #{e.message}"
              end
            else
              headers[key.downcase.to_sym] = value
              html += hdr_html(key, value)
            end
          end

          [headers, html]
        end

        def get_inline_attachment_data(msg, cid)
          msg.attachments.each do |attachment|
            next unless attachment.inline? && attachment.has_content_id?
            next unless attachment.cid == cid

            begin
              return {
                mime_type: attachment.mime_type,
                base64: Base64.strict_encode64(attachment.body.decoded)
              }
            rescue NoMethodError
              # do nothing, attachment.data is not a stream
            end
          end
          nil
        end

        def get_attachments(msg)
          attachments = []
          msg.parts.each do |part|
            if part.multipart?
              attachments.concat(get_attachments(part))
              next
            end
            next unless (part.attachment? && !part.inline?) || part.mime_type == 'message/rfc822'
            attachments << part
          end
          attachments
        end

        def get_attachment_info(attachment)
          if attachment.mime_type == 'message/rfc822'
            mail = Mail.new(attachment.body.decoded)
            {
              data: attachment.body.decoded,
              embedded_msg: mail,
              filename: "#{mail.subject || 'email'}.eml"
            }

          elsif attachment.class == Mail::Part && attachment.mime_type != 'message/rfc822' && attachment.filename

            {
              data: attachment.decoded,
              filename: attachment.filename,
              mime_type: attachment.mime_type
            }

          else
            {
              filename: attachment.content_id.to_s
            }
          end
        end

        private

        def find_hdr(list, key)
          hdr = list.find { |x| x.name.to_s =~ /^#{key}$/i }
          return nil unless hdr

          field = hdr.field
          return hdr.value unless field

          return field.decoded unless field.is_a? Mail::CommonDateField

          return field.date_time.to_time.localtime if field.respond_to?(:date_time)

          DateTime.parse(field.decoded).to_time.localtime
        end
      end
    end
  end
end
# rubocop:enable Style/Documentation, Metrics/*
