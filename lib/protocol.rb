require 'protocol'

class Protocol
  ProtocolError = Class.new(RuntimeError)

  def self.marshal(value)
    case value
    when Symbol then "+#{value.to_s.upcase}\r\n"
    when nil then "$-1\r\n"
    when String then "$#{value.length}\r\n#{value}\r\n"
    when Integer then ":#{value}\r\n"
    when Array then "*#{value.length}\r\n" + value.map {|x| marshal(x) }.join
    else raise "Don't know how to marshal: #{value.inspect}"
    end
  end

  def self.unmarshal(query_buffer)
    result    = []
    processed = 0
    io        = StringIO.new(query_buffer)

    begin
      while true
        header = safe_readline(io)

        if header[0] == '*'
          n = header[1..-1].to_i

          result << n.times.map do
            raise ProtocolError unless io.readpartial(1) == '$'
            length = safe_readline(io).to_i
            safe_readpartial(io, length).tap do
              safe_readline(io)
            end
          end
        else
          result << [:ping]
        end
        processed = io.pos
      end
    rescue EOFError
      # Try again when more data is received
    rescue ProtocolError
      # Invalid data received, throw it away
      processed = io.pos
    end
    [result, processed]
  end

  def self.safe_readline(io)
    data = io.readline

    if data[-1] == "\n"
      if data[-2] == "\r"
        data
      else
        raise ProtocolError
      end
    else
      raise EOFError
    end
  end

  def self.safe_readpartial(io, length)
    data = io.readpartial(length)
    raise EOFError unless data.length == length
    data
  end
end
