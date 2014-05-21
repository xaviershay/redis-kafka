require 'socket'
require 'logger'
require 'thread'
require 'tempfile'

require 'handler'

class Server
  def initialize(port, opts = {})
    @port          = port
    @running       = false
    @shutdown_pipe = IO.pipe
    @logger        = Logger.new(STDOUT)
    @logger.level  = opts.fetch(:log_level, Logger::INFO)

    @readable = [@shutdown_pipe[0]]
  end

  def listen
    self.running = true
    server = TCPServer.new(port)
    @readable << server
    clients = {}

    while running
      readable, _ = IO.select(@readable)

      readable.each do |socket|
        case socket
        when shutdown_pipe[0]
          running = false
        when server
          @readable << socket.accept_nonblock
        else
          handler = clients[socket] ||= Handler.new(self)
          begin
            handler.process(socket)
          rescue EOFError
            socket.close
            @readable.delete(socket)
            clients.delete(socket)
            readable.delete(socket)
            handler.shutdown
          end
        end
      end
    end
    @readable.each(&:close)
  end

  def shutdown
    self.running = false
    shutdown_pipe[1].close
  end

  attr_reader :state

  protected

  attr_accessor :running
  attr_reader   :port, :shutdown_pipe, :logger
end
