# Shared Elastic stack configuration.
# Override any field from the CLI with: nickel export ... -- field=value
# Or use NICKEL_* env vars / customize mode. See README.

{
  # URLs (used by elastic-container.sh when targeting local)
  LOCAL_KBN_URL | String = "https://127.0.0.1:5601",
  LOCAL_ES_URL | String = "https://127.0.0.1:9200",

  ELASTIC_USERNAME | String = "elastic",
  ELASTIC_PASSWORD | String = "changeme",
  KIBANA_PASSWORD | String = "changeme",

  STACK_VERSION | String = "9.0.1",
  LinuxDR | Number = 0,
  WindowsDR | Number = 0,
  MacOSDR | Number = 0,

  CLUSTER_NAME | String = "elastic-container-project",
  LICENSE | String = "basic",

  ES_PORT | String = "9200",
  KIBANA_PORT | String = "5601",
  FLEET_PORT | String = "8220",

  MEM_LIMIT | Number = 2147483648,

  # Container / service names (used by docker-compose and K8s targets)
  ELASTICSEARCH_SVC | String = "ecp-elasticsearch",
  KIBANA_SVC | String = "ecp-kibana",
  FLEET_SVC | String = "ecp-fleet-server",
}
