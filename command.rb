class Command
	@@commands = {}
	def self.commands; @@commands; end
	def self.each; @@commands.each {|name,command| yield name,command} end
	def self.[] name; @@commands[name]; end
	def self.unload; @@commands = {}; end
	attr_accessor :name, :aliases, :usage, :secure
	def initialize settings, &block
		unless @name = settings[:names].shift
			throw "At least one name must be specified"
		end
		@aliases = settings[:names]
		[@name,@aliases].flatten.each do |name|
			@@commands[name] = self
		end
		@secure = settings[:secure] || false
		@usage = settings[:usage]
		@func = block
	end
	def call from, message
		@func.call from, message
	end
	def to_s
		s = @name
		s += " or " + @aliases.join(', ') unless @aliases.empty?
		s
	end
end
