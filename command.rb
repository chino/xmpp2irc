class Command
	@@commands = {}
	def self.each; @@commands.each; end
	def self.[] name; @@commands[name]; end
	def self.unload; @@commands = {}; end
	attr_accessor :name, :usage, :secure
	def initialize settings, &block
		unless @name = settings[:names].first
			throw "At least one name must be specified"
		end
		@secure = settings[:secure] || false
		@usage = settings[:usage]
		@func = block
		settings[:names].each do |name|
			@@commands[name] = self
		end
	end
	def call from, message
		@func.call from, message
	end
end
