# AWS deployment: EKS-style Kubernetes manifests (apply with kubectl on EKS).
# For ECS/Fargate you could add a separate target that exports ECS task definition JSON.
# Usage: nickel export nickel/targets/aws.ncl --format yaml > generated/aws/stack.yaml

let config = import "../config.ncl" in
let stack_version = config.STACK_VERSION in
let cluster_name = config.CLUSTER_NAME in
let elastic_pwd = config.ELASTIC_PASSWORD in
let kibana_pwd = config.KIBANA_PASSWORD in
let es_svc = config.ELASTICSEARCH_SVC in
let kibana_svc = config.KIBANA_SVC in

# EKS uses standard Kubernetes resources; optionally add AWS-specific annotations.
{
  apiVersion = "v1",
  kind = "List",
  items = [
    {
      apiVersion = "v1",
      kind = "Namespace",
      metadata = {
        name = "elastic",
        labels = { "app.kubernetes.io/name" = "elastic-stack" }
      }
    },
    {
      apiVersion = "v1",
      kind = "Secret",
      metadata = { name = "elastic-credentials", namespace = "elastic" },
      type = "Opaque",
      stringData = {
        "elastic-password" = elastic_pwd,
        "kibana-password" = kibana_pwd
      }
    },
    {
      apiVersion = "apps/v1",
      kind = "Deployment",
      metadata = { name = es_svc, namespace = "elastic", labels = { "app" = es_svc } },
      spec = {
        replicas = 1,
        selector = { matchLabels = { "app" = es_svc } },
        template = {
          metadata = { labels = { "app" = es_svc } },
          spec = {
            initContainers = [
              {
                name = "increase-vm-max-map",
                image = "busybox:1.36",
                command = ["sysctl", "-w", "vm.max_map_count=262144"],
                securityContext = { privileged = true }
              }
            ],
            containers = [
              {
                name = "elasticsearch",
                image = "docker.elastic.co/elasticsearch/elasticsearch:%{stack_version}",
                env = [
                  { name = "node.name", value = es_svc },
                  { name = "cluster.name", value = cluster_name },
                  { name = "ELASTIC_PASSWORD", valueFrom = { secretKeyRef = { name = "elastic-credentials", key = "elastic-password" } } },
                  { name = "discovery.type", value = "single-node" },
                  { name = "xpack.security.enabled", value = "true" },
                  { name = "ES_JAVA_OPTS", value = "-Xms512m -Xmx512m" }
                ],
                ports = [{ containerPort = 9200 }, { containerPort = 9300 }],
                resources = { requests = { memory = "1Gi", cpu = "500m" }, limits = { memory = "2Gi", cpu = "1000m" } }
              }
            ]
          }
        }
      }
    },
    {
      apiVersion = "v1",
      kind = "Service",
      metadata = { name = es_svc, namespace = "elastic" },
      spec = {
        selector = { "app" = es_svc },
        ports = [
          { name = "http", port = 9200, targetPort = 9200 },
          { name = "transport", port = 9300, targetPort = 9300 }
        ]
      }
    },
    {
      apiVersion = "apps/v1",
      kind = "Deployment",
      metadata = { name = kibana_svc, namespace = "elastic", labels = { "app" = kibana_svc } },
      spec = {
        replicas = 1,
        selector = { matchLabels = { "app" = kibana_svc } },
        template = {
          metadata = { labels = { "app" = kibana_svc } },
          spec = {
            containers = [
              {
                name = "kibana",
                image = "docker.elastic.co/kibana/kibana:%{stack_version}",
                env = [
                  { name = "SERVER_NAME", value = kibana_svc },
                  { name = "ELASTICSEARCH_HOSTS", value = "https://%{es_svc}:9200" },
                  { name = "ELASTICSEARCH_USERNAME", value = "kibana_system" },
                  { name = "ELASTICSEARCH_PASSWORD", valueFrom = { secretKeyRef = { name = "elastic-credentials", key = "kibana-password" } } },
                  { name = "ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES", value = "config/certs/ca.crt" },
                  { name = "SERVER_SSL_ENABLED", value = "true" },
                  { name = "SERVER_SSL_CERTIFICATE", value = "config/certs/tls.crt" },
                  { name = "SERVER_SSL_KEY", value = "config/certs/tls.key" },
                  { name = "SERVER_SSL_CERTIFICATEAUTHORITIES", value = "config/certs/ca.crt" }
                ],
                ports = [{ containerPort = 5601 }],
                volumeMounts = [
                  { name = "certs", mountPath = "/usr/share/kibana/config/certs", readOnly = true }
                ],
                resources = { requests = { memory = "512Mi", cpu = "250m" }, limits = { memory = "1Gi", cpu = "500m" } }
              }
            ],
            volumes = [
              { name = "certs", secret = { secretName = "kibana-certs" } }
            ]
          }
        }
      }
    },
    {
      apiVersion = "v1",
      kind = "Service",
      metadata = { name = kibana_svc, namespace = "elastic" },
      spec = {
        selector = { "app" = kibana_svc },
        ports = [{ name = "http", port = 5601, targetPort = 5601 }]
      }
    }
  ]
}
