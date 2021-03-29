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
```
After a few minutes browse to http://localhost:5601 and log in with `elastic:password`.

### Stopping

Stopping this will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elk` container network

```
sh elastic-container.sh stop
```

### Status

Return the status of the containers.

```
sh elastic-container.sh status
```
