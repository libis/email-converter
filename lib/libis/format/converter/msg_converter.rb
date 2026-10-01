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

require 'mapi/msg'
require 'rfc_2047'
require 'word_wrap'

Mapi::Log.level = :error

module Libis
  module Format
    module Converter
      class MsgConverter < EmailConverter
        register :msg, :html
        register :msg, :pdf

        protected

        def open_email(source)
          Mapi::Msg.open(source)
        rescue StandardError => e
          raise "Failed to open message: #{e.message}"
        end

        def close_email(msg)
          msg.close
        end

        def get_body_html(msg)

          # Get the body of the message in HTML
          body = msg.properties.body_html

          # Embed plain body in HTML as a fallback
          body ||= HTML_WRAPPER_TEMPLATE % WordWrap.ww(msg.properties.body, 120, false) if msg.properties.body

          # Worst case, just create empty body
          body ||= HTML_WRAPPER_TEMPLATE % ''

          encoding = body.scan(/<\?xml\s[^?>]*encoding="([^"]*)"[^?>]*\?>/).flatten.first
          encoding ||= body.scan(/<meta\s+[^>]*charset=["']?([^"'>\s]+)["']?[^>]*>/).flatten.first
          encoding ||= 'UTF-8'

          body.force_encoding(encoding)

          body
        end

        def get_subject(msg)
          find_hdr(msg, 'Subject') || ''
        end

        def get_headers(msg)
          headers = {}
          html = ''

          %w[From To Cc Subject Date].each do |key|
            value = find_hdr(msg, key)
            next unless value

            if key.casecmp('Date').zero?
              value = DateTime.parse(value).to_time.localtime if value.is_a?(String)
              headers[key.downcase.to_sym] = value.iso8601
              html += hdr_html(key, value.rfc2822)
            else
              headers[key.downcase.to_sym] = value
              html += hdr_html(key, value)
            end
          end

          [headers, html]
        end

        def get_inline_attachment_data(msg, cid)
          msg.attachments.each do |attachment|
            next unless decode(attachment.properties.attach_content_id) == cid

            attachment.data.rewind
            return {
              mime_type: decode(attachment.properties.attach_mime_tag),
              base64: Base64.encode64(attachment.data.read).gsub(/[\r\n]/, '')
            }
          end
          nil
        end

        def get_attachments(msg)
          msg.attachments.select do |attachment|
            !attachment.properties.attachment_hidden
          end
        end

        def get_attachment_info(attachment)
          if attachment.data.class == Mapi::Msg

            {
              embedded_msg: attachment.data,
              filename: decode(attachment.filename) || decode(attachment.properties.display_name || attachment.message&.subject || 'email') + '.msg',
            }

          elsif attachment.filename
            attachment.data.rewind
            {
              data: attachment.data.read,
              filename: decode(attachment.filename),
              mime_type: decode(attachment.properties.attach_mime_tag || 'application/octet-stream'),
            }

          else
            {
              filename: decode(attachment.properties.attach_mime_tag) || 'unknown',
            }
          end
        end

        private

        private

        def find_hdr(msg, key)
          keys = msg.headers.keys
          if (k = keys.find { |x| x.to_s =~ /^#{key}$/i })
            v = msg.headers[k]
            v = v.first if v.is_a? Array
            v = decode(v) if v.is_a? String
            return v
          end
          nil
        end

        def decode(value)
          return value unless value.is_a?(String)

          begin
            Rfc2047.decode(value).strip.gsub(/\u0000/, '')
          rescue StandardError
            value
          end
        end
      end
    end
  end
end
