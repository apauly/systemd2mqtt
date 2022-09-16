require 'bundler/inline'

MQTT_URL = ENV['MQTT_URL'] || raise 'Please provide an MQTT_URL env variable'
HOSTNAME = ENV['HOSTNAME'] || `hostname`.strip.split('.').first
ALLOWED_SERVICES = ENV['SERVICES']&.split(',')&.map(&:strip) || raise 'Please provide SERVICES as an env variable containing a comma seperated list of services that should be allowed to use'

gemfile do
  source 'https://rubygems.org'
  gem 'mqtt'
  gem 'json'
  gem 'em-mqtt'
end

at_exit do
  $mqtt&.disconnect
  EM.stop
end

def publish_service_status(service, force_state: nil)
  force_state ||= begin
    `systemctl is-active --quiet #{service}`
    $?.exitstatus == 0 ? 'ON' : 'OFF'
  end
  puts "SEND systemctl/#{HOSTNAME}/#{service} - #{{ state: force_state }.to_json}"
  $mqtt.publish "systemctl/#{HOSTNAME}/#{service}", { state: force_state }.to_json, true # last param: retain=true
end

def state_from_payload(payload)
  return payload if ['ON', 'OFF'].include?(payload)

  JSON.parse(payload)['state']
end

EventMachine.run do
  $mqtt = EventMachine::MQTT::ClientConnection.connect(MQTT_URL)
  $mqtt.subscribe("systemctl/#{HOSTNAME}/+/get")
  $mqtt.subscribe("systemctl/#{HOSTNAME}/+/set")

  puts "Listening to systemctl/#{HOSTNAME}/<service>/(get|set)"

  $mqtt.receive_callback do |packet|
    _, hostname, service, action = packet.topic.split('/')
    next unless hostname == HOSTNAME
    next unless ALLOWED_SERVICES.include?(service)

    if action == 'set'
      case state_from_payload(packet.payload)
      when 'ON'
        puts "START #{service}"
        `systemctl start #{service}`
      when 'OFF'
        puts "STOP #{service}"
        `systemctl stop #{service}`
      end
    end

    publish_service_status(service)
  end

  ALLOWED_SERVICES.each do |service|
    publish_service_status(service)
  end
end
