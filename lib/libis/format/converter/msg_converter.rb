# frozen_string_literal: true

require_relative 'email_converter'

require 'msg_extractor'
require 'word_wrap'

module Libis
  module Format
    module Converter
      class MsgConverter < EmailConverter
        register :msg, :html
        register :msg, :pdf

        protected

        def open_email(source)
          msg = nil

          # Open the message
          msg = MsgExtractor.open(source)

          unless msg.is_a?(MsgExtractor::Message)
            raise "File #{File.basename(source)} is not an Outlook message but a #{msg.class.name}"
          end

          msg
        rescue StandardError => e
          raise "Failed to open message: #{e.message}"
        end

        def close_email(_msg)
          true
        end

        def get_body_html(msg)
          # Get the body of the message in HTML
          body = msg.html_body

          # Embed plain body in HTML as a fallback
          body ||= HTML_WRAPPER_TEMPLATE % WordWrap.ww(msg.body, 120, false)

          # Worst case, just create empty body
          body ||= HTML_WRAPPER_TEMPLATE % ''

          body
        end

        def get_subject(msg)
          msg.subject || ''
        end

        def get_headers(msg)
          headers = {}
          html = ''

          %w[From To Cc Subject Date].each do |key|
            value = find_hdr(msg, key)
            next unless value

            if key.casecmp('Date').zero? && value.is_a?(Time)
              headers[key.downcase.to_sym] = value.iso8601
              html += hdr_html(key, value.rfc2822)
            else
              headers[key.downcase.to_sym] = value
              html += hdr_html(key, value)
            end
          end

          [headers, html]
        end

        def get_inline_attachment_data(attachments, cid)
          attachments.each do |attachment|
            next unless attachment.content_id == cid

            return {
              mime_type: attachment.mime_type,
              base64: Base64.encode64(attachment.data).gsub(/[\r\n]/, '')
            }
          end
          nil
        end

        def get_file_attachments(attachments, _used_files)
          attachments.select do |attachment|
            !attachment.content_id && !attachment.embedded_message? && attachment.filename
          end
        end

        def get_mail_attachments(attachments)
          attachments.select(&:embedded_message?)
        end

        def get_attachment_info(attachment)
          if attachment.embedded_message?

            {
              embedded_msg: attachment.data,
              filename: attachment.message&.subject || 'email'
            }

          elsif attachment.filename

            {
              data: attachment.data,
              filename: attachment.filename
            }

          else
            {
              filename: attachment.mime_type || 'unknown'
            }
          end
        end

        private

        def find_hdr(msg, key)
          value = if key.casecmp('From').zero?
                    msg.sender
                  else
                    msg.send(key.downcase.to_sym)
                  end

          if value.is_a?(Array)
            value.compact.empty? ? nil : value.compact.map(&:to_s).join(', ')

          elsif value.is_a?(Time)
            value.localtime

          else
            value.to_s

          end
        end
      end
    end
  end
end
