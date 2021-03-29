# Elastic Container
Stand up a simple Elastic container with Kibana, Fleet, and the Detection Engine

## Usage
This uses default creds of `elastic:password` and is intended purely for rapid testing a local Elastic stack.

There is zero security enabled, beyond basic auth, and this should not be Internet exposed or used anywhere in production.

There is zero saved data, everything is wiped when the containers are stopped. Again, not meant for anything but testing.

### Starting

Running this will:
- create a network called `elastic`
- download the 7.12.0 Elasticsearch and Kibana Docker containers
- start Elasticsearch and Kibana containers w/all settings needed for Fleet and the Detection Engine

```
$ sh elastic-container.sh start

7963e312e00023539389d9176e971d6c4bede17f591195aa44864b815a723aaa
1219144625de8a0b59e478d917b88ddff690fb8685a9ee6e54a2fa7cdfdf4073
8c88d8f74d46e40c5b74963a641de1de422855163d8a146281a0cec03df4635a
```
After a few minutes browse to http://localhost:5601 and log in with `elastic:password`.

### Stopping

Stopping this will:
- stop the Elasticsearch and Kibana containers
- delete the Elasticsearch and Kibana containers
- delete the `elastic` container network

```
$ sh elastic-container.sh stop

elasticsearch
kibana
elastic
```

### Status

Return the status of the containers.

```
$ sh elastic-container.sh status

NAMES: STATUS
kibana: Up 16 seconds
elasticsearch: Up 17 seconds
```

## Modifying

In `elastic-container.sh`, the variables are defined, any can be changed.
```
ELASTIC_PASSWORD="password"
ELASTICSEARCH_URL="http://elasticsearch:9200"
STACK_VERSION="7.12.0"
```

If you want to change the default values, simply replace whatever is appropriate in the variable declaration.

If you want to use different Elastic Stack versions, you can change those as well. Optional values are on Elastic's Docker hub:

- [Elasticsearch](https://hub.docker.com/r/elastic/elasticsearch/tags?page=1&ordering=last_updated)
- [Kibana](https://hub.docker.com/r/elastic/kibana/tags?page=1&ordering=last_updated)

## Questions

1. But...why?  
To test data feeds, ingest pipelines, detection rules, Fleet configs...w/e. Something I could blow away fast but had the bare necessities.

1. Why don't you use Docker Compose?  
Old habbits.

1. This is horrible, why can't you write better scripts?  
Function over beauty.

1. I suppose I can use this, can I change the creds or stack version?  
Of course.

1. Why did you use a mounted Kibana config but Elasticsearch environment variables?  
I tried with Kibana variables, but they all didn't seem to work right and the config worked.
