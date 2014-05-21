require 'parser'

require 'poseidon'

class Handler
  def initialize(server)
    @parser   = Parser.new
    @producer = Poseidon::Producer.new(["localhost:9092"], "queue1")
    # lol marshal
    @consumers = Marshal.load(File.read('state_file')) rescue {}
  end

  attr_reader :parser, :tx

  def shutdown
  end

  def process(socket)
    parser.parse(socket.read_nonblock(1024)).each do |argv|
      response = dispatch(argv)

      write_response socket, response
      # lol marshal
      File.write('state_file', Marshal.dump(@consumers))
    end
  end

  def dispatch(cmd)
    case cmd[0].to_s.downcase
    when "lpush" then
      messages = []
      messages << Poseidon::MessageToSend.new(cmd[1], cmd[2])
      @producer.send_messages(messages)
      nil
    when "rpop" then
      topic = cmd[1]
      high_water = @consumers[topic] ||= :earliest_offset
      # This is hella inefficient
      consumer = Poseidon::PartitionConsumer.new(
        "some_consumer", "localhost", 9092, topic, 0, high_water)
      messages = consumer.fetch
      message = messages[0]
      if message
        @consumers[topic] = message.offset + 1
        message.value
      end
    else 
      # there is actually a protocol for this
      "ERR Unknown command"
    end
  end

  def write_response(socket, response)
    socket.write Protocol.marshal(response)
  end
end
