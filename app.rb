ENV["RACK_ENV"] ||= "development"
require 'bundler/setup'
require_relative './ispy'
require_relative './ffmpeg'
Bundler.require(:default, ENV["RACK_ENV"].to_sym)

class Peer
  attr_accessor :socket

  def initialize(socket)
    @socket = socket
  end

  def <<(message)
    EM.next_tick do
      @socket.send message.to_json
    end
  end
end

class Room
  attr_accessor :id, :caller, :callee, :offer

  def initialize(id, caller)
    @id     = id
    @caller = caller
  end
end

class WebRTC < Sinatra::Base

  set :server, :thin
  ffserver_conf = "#{File.dirname(__FILE__)}/ffmpeg/ffserver.conf"
  encoder = FFMPEG.new(ffserver_conf)

  configure :development do
    # Make application reload automatically for
    # each request in development environment
    register Sinatra::Reloader

    # Use SASS
    require "sass/plugin/rack"
    use Sass::Plugin::Rack

    # Use Coffeescript
    require "rack/coffee"
    use Rack::Coffee, root: "public", urls: "/javascript"
  end

  @@rooms = {}

  get "/" do
    erb :application
  end

  post "/control" do
    puts " parameter is: #{params[:command]}"
    if params[:command] == "connect"
      puts "Connecting to bot"
      $i = ISPY.new("10.10.1.1","8150")
    elsif params[:command] == "disconnect"
      puts "Disconnecting from bot"
      $i.disconnect
    end
  end
  
  post "/commands" do
    puts " parameter is: #{params[:command]}"
    $i.send(params[:command])
  end

  post "/video" do
    if params[:command] == "start"
      encoder.start
    elsif params[:command] == "stop"
      encoder.stop
    end
  end

  get "/socket" do
    if request.websocket?
      request.websocket do |socket|

        socket.onmessage do |message|
          catch(:halt) do

            begin
              message = JSON.parse(message)
            rescue JSON::ParserError
              halt
            end

            room = @@rooms[message["room_id"]]

            case message["type"]

            when "connect"
              halt if !message["room_id"]

              if room
                if room.callee          # Room occupied by two peers, send error
                  Peer.new(socket) << { type: "error-room-occupied" }
                else                    # Only 1 peer, connect to the room
                  room.callee = Peer.new(socket)
                  room.callee << { type: "offer", offer: room.offer } if room.offer
                end
              else                      # No room yet, create it
                room = Room.new(message["room_id"], Peer.new(socket))
                @@rooms[message["room_id"]] = room
                room.caller << { type: "no-room" }
              end


            when "offer"
              halt if !room
              halt if socket != room.caller.socket
              halt if !message["room_id"] or !message["offer"]

              room.offer = message["offer"]
              room.callee << { type: "offer", offer: room.offer } if room.callee


            when "answer"
              halt if !room
              halt if socket != room.callee.socket
              halt if !message["room_id"] or !message["answer"]

              room.caller << { type: "answer", answer: message["answer"] }


            when "ice-candidate"
              halt if !room
              halt if socket != room.caller.socket and socket != room.callee.socket
              halt if !message["room_id"] or !message["ice_candidate"]

              other = (socket == room.caller.socket ? room.callee : room.caller)
              halt if !other
              other << { type: "ice-candidate", ice_candidate: message["ice_candidate"] }


            when "close"
              halt if !message["room_id"]
              if room
                halt if socket != room.caller.socket and socket != room.callee.socket

                other = (socket == room.caller.socket ? room.callee : room.caller)
                other << { type: "other-left" } if other
                @@rooms.delete(message["room_id"])
              end

            end
          end
        end
      end

    else
      404
    end

  end

  run! if app_file == $0
end

