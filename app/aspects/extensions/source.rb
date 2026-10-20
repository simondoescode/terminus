# auto_register: false
# frozen_string_literal: true

require "core"
require "csv"
require "dry/monads"
require "functionable"
require "json"
require "nori"
require "refinements/string"

module Terminus
  module Aspects
    module Extensions
      # Sources supported data types into a hash for further processing.
      module Source
        extend Dry::Monads[:result]
        extend Functionable

        using Refines::Icalendar::Calendar
        using Refinements::String

        def from_calendar content, parser: Icalendar::Parser
          Success StringIO.new(without_unsupported_alarm_relationships(content))
                          .then { parser.new(it, true).parse }
                          .map(&:to_h)
        rescue StandardError => error
          Failure error.message
        end

        # RELATED-TO is an event property, not a VALARM property. Some feeds
        # include it in alarms; the icalendar parser then calls an undefined
        # Alarm#related_to= setter. Preserve alarms and all other properties.
        def without_unsupported_alarm_relationships content
          alarm_pattern = /^BEGIN:VALARM[^\r\n]*\r?\n.*?^END:VALARM[^\r\n]*(?:\r?\n|\z)/im
          relationship_pattern = /
            ^RELATED-TO(?:;[^:\r\n]*)?:[^\r\n]*
            (?:\r?\n[ \t][^\r\n]*)*(?:\r?\n|\z)
          /ix

          String(content).gsub(alarm_pattern) { |alarm| alarm.gsub relationship_pattern, "" }
        end

        def from_csv content
          Success ::CSV.parse(String(content), headers: true).each.map(&:to_h)
        rescue ::CSV::MalformedCSVError => error
          Failure error.message
        end

        def from_image(content) = Success content

        def from_json content
          content = String(content).empty? ? Core::EMPTY_ARRAY : JSON(content)
          Success content
        rescue ::JSON::ParserError => error
          Failure "#{error.message.up}."
        end

        def from_text content
          Success String(content).split
        rescue ArgumentError => error
          Failure "#{error.message.up}."
        end

        def from_xml content, nori: Nori.new(parser: :rexml)
          content = nori.parse String(content)
          Success content.empty? ? Core::EMPTY_ARRAY : content
        rescue REXML::ParseException => error
          Failure error.message
        end
      end
    end
  end
end
