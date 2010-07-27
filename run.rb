#!/usr/bin/env ruby
require 'rubygems'
require 'xmpp4r-simple'
require 'optparse'
require 'net/yail'
require 'command'
require 'irc'

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [-d|--debug]"
	opts.on("-h","--help","This help"){|v| puts opts; exit 0}
	opts.on("-d","--debug","Enable Debugging"){|v|
		Jabber::debug = true
	}
end.parse!

## globals

load 'settings.rb'

MAIN = __FILE__     # main script
$irc = nil          # target irc server for messages
$channel = nil      # target channel for messages
$forward = $master  # target jabber id for messages

## xmmp connection and helpers

def authorized? name
	$master_regex ||= /^#{$master.gsub('.','\.')}(\/.*)?$/
	name.to_s =~ $master_regex
end

begin
	$im = Jabber::Simple.new $login, $passwd
rescue Jabber::ClientAuthenticationFailure
	puts "xmpp authentication failed"
	exit 1
end

def send to, msg
	$im.deliver to, msg
	puts "#{to} < #{msg}"
end

$im.status :chat, $status
$im.accept_subscriptions = true
send $master, "Started @ #{Time.now}"

## load user commands and local init file

load 'commands.rb'

def run name, *args # easy command api for init file
	if command = Command[name]
		if response = command.call( $master, "/#{name} #{args.join(' ')}" )
			send $master, response
		end
	else
		throw "unknown command #{name}"
	end
end

load 'init.rb'

## main

$xmpp_main = Proc.new{

	# subscribe to anyone who subscribes to us
	$im.new_subscriptions {|friend, presence|
		$im.add friend.jid
  	  puts "subscribed to #{friend}"
	}

	# handle incoming messages
	$im.received_messages{|msg|
		next unless msg.type == :chat

		# forward any received messages to the master for visibility
		to = (msg.from.to_s =~ /#{$login}/) ? "" : " to #{msg.to}"
		info = "#{msg.from.to_s} #{to} > #{msg.body}"
		authorized?(msg.from) ? puts(info) : send($master, info)

		# subscribe to anyone who messages us
		$im.add msg.from unless $im.subscribed_to?(msg.from)

		# run command
		name = msg.body.split.first.delete('/')
		if command = Command[name]
			if command.secure and not authorized? msg.from
				send msg.from, "#{msg.from} is not authorized to run #{command.name}"
			else
				response = command.call msg.from, msg.body
				if response.respond_to? :empty? and not response.empty?
					send msg.from, response
				end
			end

		# for the master send unknown text to default irc channel
		elsif authorized? msg.from
			parts = msg.body.split
			msg.body = parts.join(' ')
			if $irc.dead_socket
				send $master, "sorry but the connection to #{$irc.server} is dead"
			else
				$irc.msg $channel, msg.body
			end

		# for public
		else
			send msg.from, "unknown command"
		end
	}

}

$last_dead = {}
$irc_main = Proc.new{
	Irc.each do |server,connection|
		now = Time.now
		next unless connection.dead_socket
		next unless now - ($last_dead[connection]||now-30) >= 30
		$last_dead[connection] = now
		send $master, "#{now} lost irc connection to #{server} trying to reconnect"
		connection.connect
	end
}

loop do
	begin
		$irc_main.call
		$xmpp_main.call
	rescue Exception => e
		send $master, "error = #{e}\n#{e.backtrace.join("\n")}"
	end
	sleep 1
end
