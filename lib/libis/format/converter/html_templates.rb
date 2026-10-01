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
