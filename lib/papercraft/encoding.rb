# frozen_string_literal: true

module Papercraft
  # Papercraft::Encoding includes common encoding methods
  module Encoding
    # Encodes the given string to safe HTML text, converting special characters
    # into the respective HTML entities. If a non-string value is given, it is
    # converted to `String` using `#to_s`.
    #
    # @param text [String] string to be encoded
    # @return [String] HTML-encoded string
    def __html_encode__(text)
      EscapeUtils.escape_html(text.to_s)
    end

    # Encodes the given string to safe URI component, converting special
    # characters to URI entities. If a non-string value is given, it is
    # converted to `String` using `#to_s`.
    #
    # @param text [String] string to be encoded
    # @return [String] URI-encoded string
    def __uri_encode__(text)
      EscapeUtils.escape_uri(text.to_s)
    end
  end
end
