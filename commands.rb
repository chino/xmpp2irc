Command.new({ :names => ["help","h"], :usage =>  "This help message"}) do |from,message|
	name = message.split[1]
	if name
		if command = Command[name]
			if command.secure and authorized? from
				return "#{name}: #{Command[name][:usage]}"
			end
		end
		"unknown command"
	else
		names = []
		def format names
			name = names.shift
			unless names.empty?
				name += " aliases #{names.join(',')}"
			end
			name
		end
		if authroized? from
			Command.each {|name,command| names << format(command.names.dup) }
		else
			Command.each {|name,command| names << format(command.names.dup) unless command.secure }
		end
		"commands: #{$commands.keys.join('; ')}"
	end
end
Command.new({ :names => ["ping","p"], :usage => "Ping test"}) do |from,message|
	"Pong"
end
Command.new({ :names => ["authorized?","a"], :usage => "Check if your authorization", :secure =>true }) do |from,message|
	"Yes"
end
Command.new({ :names => ["restart","r"], :usage => "Restart", :secure =>true }) do |from,message|
	exec MAIN
end
Command.new({ :names => ["config","cf"], :usage => "Reload config", :secure =>true }) do |from,message|
	Command.unload
	load 'config'
	"config has been reloaded"
end
Command.new({ :names => ["forward","f"], :usage => "Control forwarding of messages: [off|all|nil=from]", :secure =>true }) do |from,message|
	parts = message.split
	command = message.shift
	case message.shift
	when "off"
		$forward = nil
		"messages forwarding turned off"
	when "all"
		$forward = $master
		"messages forwarding to all resources"
	else
		$forward = from
		"messages forwarding only to #{from}"
	end
end
Command.new({ :names => ["join","j"], :usage => "Join a channel and set it as the default target: <channel>", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	channel = parts.shift
	$channels.unshift(channel).uniq!
	$irc.join channel
	$channel = channel
	"joined #{channel} target is now #{$channel}"
end
Command.new({ :names => ["part","p"], :usage => "Leave a channel: <channel>", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	channel = parts.shift
	$irc.part channel
	$channels.delete channel
	$channel = $channels.first
	"parted #{channel} target is now #{$channel}"
end
Command.new({ :names => ["privmsg","m"], :usage => "Send an irc message: <target> <message>", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	target = parts.shift
	message = parts.join(' ')
	$irc.msg target, message
	nil
end
Command.new({ :names => ["message","xm"], :usage => "Send a xmpp message: <target> <message>", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	target = parts.shift
	message = parts.join(' ')
	send target, message
	nil
end
# TODO: how do i see the results?
Command.new({ :names => ["names","n"], :usage => "Get list of user names for a channel: <channel>", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	channel = parts.shift || $channel
	$irc.names channel
	"requested name list for #{channel}"
end
Command.new({ :names => ["connect","c"], :usage => "Connect to an irc server (specify only <server> to set it as the target if already connected): <server> <nick>[:passwd] <channels>", :secure => true }) do |from,message|
	parts = message.split
	command = parts.shift
	server = parts.shift
	nick = parts.shift
	nick,passwd = nick.split(':') if nick =~ /:/
	channels = parts
	$channel = channels.first
	$irc = Irc.new(server,nick,passwd,channels,{
		:incoming_msg => Proc.new{|fullactor,actor,target,text|
			from = actor
			from += " @ #{target}" if target != $channel
			send $forward, "#{from} > #{text}" unless $forward.nil?
		},
		:incoming_namreply => Proc.new{|text,args|
			text =~ /^(@|\*|=) (\S+) :?(.+)$/
			type,channel,users = $1,$2,$3
			send $forward, "users in #{channel}: #{users}"
		}
	})
	"target is now #{$irc.server}@#{$channel}"
end
Command.new({ :names => ["leave","l"], :usage => "Leave an irc server: <server>", :server => true }) do |from,message|
	parts = message.split
	commands = parts.shift
	server = parts.shift 
	if connection = Irc[server]
		connection.quit
		"quiting #{server}"
	else
		"could not find #{server}"
	end
end
