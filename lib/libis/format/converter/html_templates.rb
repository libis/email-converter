# frozen_string_literal: true

module Libis
  module Format
    module Converter
      HEADER_STYLE = <<~HTML
        <style>
          .header-table {
            margin: 0 0 10px 0;
            padding: 0;
            font-family: Arial, Helvetica, sans-serif;
          }
          .header-table table {
            width: 100%;
          }
          .header-name {
            padding-right: 5px;
            color: #9E9E9E;
            text-align: right;
            vertical-align: top;
            font-size: 12px;
          }
          .header-value {
            font-size: 12px;
            width: 99%;
          }
          .header_fields {
            background: white;
            margin: 0;
            border: 1px solid #DDD;
            border-radius: 3px;
            padding: 8px;
            box-sizing: border-box;
          }
        </style>
      HTML

      HEADER_TABLE_TEMPLATE = <<~HTML
        <div class="header-table">
          <table class="header_fields">
            <tbody>
        %s
            </tbody>
          </table>
        </div>
      HTML

      HEADER_FIELD_TEMPLATE = <<~HTML
        <tr>
          <td class="header-name">%s</td>
          <td class="header-value">%s</td>
        </tr>
      HTML

      HTML_WRAPPER_TEMPLATE = <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <style>
              body {
                font-size: 12px;
                }
            </style>
            <title>title</title>
          </head>
          <body>
            <pre>
        %s
            </pre>
          </body>
        </html>
      HTML

      HTML_BODY_TEMPLATE = <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <style>
              body {
                font-size: 12px;
              }
            </style>
            <title>title</title>
          </head>
          <body>
            %s
          </body>
        </html>
      HTML

      ATTACHMENT_STYLE = <<~HTML
        <style>
          .attachment-list {
            border: 1px solid #DDD;
            margin: 0 0 10px 0;
            padding: 0;
            font-family: Arial, Helvetica, sans-serif;
          }
          .attachment-list ul {
            list-style: disclosure-closed;
            margin: 8px 0 8px 0;
          }
          .attachment-list li {
            font-size: 12px;
            padding-left: 1em;
          }
        </style>
      HTML

      ATTACHMENT_LIST_TEMPLATE = <<~HTML
        <div class="attachment-list">
          <ul>
        %s
          </ul>
        </div>
      HTML

      HTML_DOCTYPE_TEMPLATE = '<!DOCTYPE html>%s'
      ATTACHMENT_ITEM_TEMPLATE = '<li>%s</li>'

      IMG_CID_PLAIN_REGEX = /\[cid:(.*?)\]/im
      IMG_CID_HTML_REGEX = /cid:([^"]*)/im
    end
  end
end
