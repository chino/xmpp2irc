class Irc
	@@connections = {}
	def self.connections; @@connections; end
	def self.each; @@connections.each {|name,connection| yield name,connection} end
	def self.[] name; @@connections[name]; end
	attr_accessor :server, :nick, :channels
	def initialize server, nick, passwd, channels, callbacks
		return if @@connections[server] # only one connection per server
		@server = server
		@nick = nick
		@channels = channels
		@callbacks = callbacks
		@settings = {
			:address => @server,
			:username => @nick,
			:realname => @nick,
			:nicknames => [@nick],
			:server_password => passwd
		}
		@@connections[server] = self
		connect
	end
	def connect
		@irc = Net::YAIL.new @settings
		@irc.prepend_handler :incoming_welcome, proc {|text,args|
			@channels.each {|channel| @irc.join channel }
			return false
		}
		@callbacks.each do |event,callback|
			@irc.prepend_handler event, callback
		end
		@irc.start_listening
	end
	def quit *args
		@@connections.delete @server
		@irc.quit *args
	end
	def method_missing meth, *args
		@irc.__send__ meth, *args
	end
end
