# Elastic Container
Stand up a simple Elastic container with Kibana, Fleet, and the Detection Engine

## Usage
This uses default creds of `elastic:password` and is intended purely for rapid testing a local Elastic stack.

There is zero security enabled and this should not be Internet exposed or use anywhere in production.

There is zero saved data, everything is wiped when the containers are stopped. Again, not meant for anything but testing.

### Starting

Running this will:
- create a network called `elk`
- download the 8.0.0 Elasticsearch and Kibana Docker containers
- start Elasticsearch and Kibana containers w/all settings needed for Fleet and th Detection Engine

```
sh elastic-container.sh start

7963e312e00023539389d9176e971d6c4bede17f591195aa44864b815a723aaa
1219144625de8a0b59e478d917b88ddff690fb8685a9ee6e54a2fa7cdfdf4073
8c88d8f74d46e40c5b74963a641de1de422855163d8a146281a0cec03df4635a
```
After a few minutes browse to http://localhost:5601 and log in with `elastic:password`.

### Stopping

Stopping this will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elk` container network

```
sh elastic-container.sh stop

elasticsearch
kibana
elk
```

### Status

Return the status of the containers.

```
sh elastic-container.sh status

NAMES: STATUS
kibana: Up 16 seconds
elasticsearch: Up 17 seconds
```

## Questions

1. Why don't you use Docker Compose?
Habbits.

2. This is horrible, why can't you write better scripts?
Function over beauty.

3. I suppose I can use this, can I change the creds or stack version?
Of course.
