require 'stringio'

require 'protocol'

class Parser
  def initialize
    @query_buffer = ""
  end

  def parse(buffer)
    query_buffer << buffer

    result, processed = Protocol.unmarshal(query_buffer)
    @query_buffer = query_buffer[processed..-1]
    result
  end

  attr_reader :query_buffer
end
