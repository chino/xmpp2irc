Command.new({ :names => ["help","h"], :usage =>  "This help message"}) do |from,message|
	name = message.split[1]
	if name
		if command = Command[name]
			if command.secure
				if authorized? from
					next "#{name}: #{Command[name].usage}"
				end
			else
				next "#{name}: #{Command[name].usage}"
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
Command.new({ :names => ["ping"], :usage => "Test responsiveness"}) do |from,message|
	"Pong"
end
Command.new({ :names => ["authorized?"], :usage => "Check if your authorized", :secure =>true }) do |from,message|
	"Yes"
end
Command.new({ :names => ["forward","f"], :usage => "[off|all|nil=from] - Control forwarding of messages", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	arg = parts.shift
	case arg
	when "off"
		$forward = nil
		"message forwarding turned off"
	when "on"
		$forward = $master
		"message forwarding to all resources"
	else
		$forward = from
		"message forwarding only to #{from}"
	end
end
Command.new({ :names => ["join","j"], :usage => "<channel> - Join a channel and set it as the default target", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	channel = parts.shift
	$irc.channels.unshift(channel).uniq!
	$irc.join channel
	$channel = channel
	"joined #{channel} target is now #{$channel}"
end
Command.new({ :names => ["part","p"], :usage => "<channel> - Leave a channel", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	channel = parts.shift
	$irc.part channel
	$irc.channels.delete channel
	$channel = $irc.channels.first
	"parted #{channel} target is now #{$channel}"
end
Command.new({ :names => ["privmsg","m"], :usage => "<target|*> <message> - Send an irc message", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	target = parts.shift
	message = parts.join(' ')
	if target == '*'
		Irc.each do |server,connection|
			connection.channels.each do |channel|
				connection.msg channel, message
			end
		end
	else
		$irc.msg target, message
	end
	nil
end
Command.new({ :names => ["message","xm"], :usage => "<target> <message> - Send a xmpp message", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	target = parts.shift
	message = parts.join(' ')
	send target, message
	nil
end
Command.new({ :names => ["names","n"], :usage => "[channel|*] - Get list of user names for a channel.", :secure =>true }) do |from,message|
	parts = message.split
	command = parts.shift
	channel = parts.shift || $channel
	if channel == '*'
		Irc.each do |server,connection|
			connection.channels.each do |channel|
				connection.names channel
			end
		end
	else
		$irc.names channel
	end
	"requested name list for #{channel}"
end
Command.new({ :names => ["connect","c"], :usage => "<server> <nick>[:passwd] <channels> - Connect to an irc server (specify only <server> to set it as the target if already connected)", :secure => true }) do |from,message|
	parts = message.split
	command = parts.shift
	server = parts.shift
	nick = parts.shift
	nick,passwd = nick.split(':') if nick =~ /:/
	channels = parts
	$channel = channels.first
	$irc = Irc.new(server,nick,passwd,channels,{
		:incoming_msg => Proc.new{|fullactor,actor,target,text|
			user = actor
			user += "@#{target}" if target != $channel
			send $forward, "#{user} > #{text}" unless $forward.nil?
		},
		:incoming_namreply => Proc.new{|text,args|
			text =~ /^(@|\*|=) (\S+) :?(.+)$/
			type,channel,users = $1,$2,$3.gsub(/\b#{nick}\b/,'')
			send $forward, "users in #{server}@#{channel}: #{users}"
		}
	})
	"target is now #{$irc.server}@#{$channel}"
end
Command.new({ :names => ["quit"], :usage => "<server> - Quit an irc server", :server => true }) do |from,message|
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
Command.new({ :names => ["info","i"], :usage => "List irc servers and channels", :server => true }) do |from,message|
	lists = []
	Irc.each do |name,connection|
		lists << "#{name} @ { #{connection.channels.join(', ')} }"
	end
	lists.join(' ')
end
Command.new({ :names => ["target","t"], :usage => "Prints the current target", :server => true }) do |from,message|
	"target is #{$irc.server}@#{$channel}"
end
