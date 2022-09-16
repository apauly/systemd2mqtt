# systemd2mqtt

systemd2mqtt allows you to control a certain systemd based services via MQTT.

## Installation

1. Clone the repo
2. Adjust `systemd2mqtt.service` to your needs and enable it as a systemd unit
3. Start the service


## Homeassistant

In order to add a virtual switch to homeassistant that will e.g. start/stop pihole, add this to the `configuration.yaml`:

```
switch:
  - platform: mqtt
    unique_id: pihole
    name: "Pihole"
    payload_on: "ON"
    payload_off: "OFF"
    state_topic: "systemctl/<your-hostname>/pihole-FTL"
    command_topic: "systemctl/<your-hostname>/pihole-FTL/set"
    value_template: '{{ value_json.state }}'
```

## Requirements

I'm currently using this on a raspberry pi with ruby-2.7. Other environments with newer or older ruby versions might also work.
