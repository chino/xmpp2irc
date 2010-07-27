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
		Command.commands.values.uniq.each do |command|
			names << command.to_s unless command.secure and not authorized? from
		end
		"commands: #{names.join('; ')}"
	end
end
Command.new({ :names => ["ping","p"], :usage => "Ping test"}) do |from,message|
	"Pong"
end
Command.new({ :names => ["authorized?"], :usage => "Check if your authorization", :secure =>true }) do |from,message|
	"Yes"
end
Command.new({ :names => ["restart"], :usage => "Restart", :secure =>true }) do |from,message|
	exec MAIN
end
Command.new({ :names => ["reload"], :usage => "Reload config", :secure =>true }) do |from,message|
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
