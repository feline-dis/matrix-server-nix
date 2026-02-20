{ config, pkgs, ... }:

let
  alloyConfig = pkgs.writeText "config.alloy" ''
    prometheus.exporter.self "alloy_check" { }

    discovery.relabel "alloy_check" {
      targets = prometheus.exporter.self.alloy_check.targets

      rule {
        target_label = "instance"
        replacement  = constants.hostname
      }

      rule {
        target_label = "alloy_hostname"
        replacement  = constants.hostname
      }

      rule {
        target_label = "job"
        replacement  = "integrations/alloy-check"
      }
    }

    prometheus.scrape "alloy_check" {
      targets    = discovery.relabel.alloy_check.output
      forward_to = [prometheus.relabel.alloy_check.receiver]
      scrape_interval = "60s"
    }

    prometheus.relabel "alloy_check" {
      forward_to = [prometheus.remote_write.metrics_service.receiver]

      rule {
        source_labels = ["__name__"]
        regex         = "(prometheus_target_sync_length_seconds_sum|prometheus_target_scrapes_.*|prometheus_target_interval.*|prometheus_sd_discovered_targets|alloy_build.*|prometheus_remote_write_wal_samples_appended_total|process_start_time_seconds)"
        action        = "keep"
      }
    }

    prometheus.remote_write "metrics_service" {
      endpoint {
        url = "https://prometheus-prod-67-prod-us-west-0.grafana.net/api/prom/push"

        basic_auth {
          username = "2989184"
          password = env("GRAFANA_CLOUD_API_KEY")
        }
      }
    }

    loki.write "grafana_cloud_loki" {
      endpoint {
        url = "https://logs-prod-021.grafana.net/loki/api/v1/push"

        basic_auth {
          username = "1490267"
          password = env("GRAFANA_CLOUD_API_KEY")
        }
      }
    }

    discovery.relabel "integrations_node_exporter" {
      targets = prometheus.exporter.unix.integrations_node_exporter.targets

      rule {
        target_label = "instance"
        replacement  = constants.hostname
      }

      rule {
        target_label = "job"
        replacement = "integrations/node_exporter"
      }
    }

    prometheus.exporter.unix "integrations_node_exporter" {
      disable_collectors = ["ipvs", "btrfs", "infiniband", "xfs", "zfs"]

      filesystem {
        fs_types_exclude     = "^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|tmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$"
        mount_points_exclude = "^/(dev|proc|run/credentials/.+|sys|var/lib/docker/.+)($|/)"
        mount_timeout        = "5s"
      }

      netclass {
        ignored_devices = "^(veth.*|cali.*|[a-f0-9]{15})$"
      }

      netdev {
        device_exclude = "^(veth.*|cali.*|[a-f0-9]{15})$"
      }
    }

    prometheus.scrape "integrations_node_exporter" {
      targets    = discovery.relabel.integrations_node_exporter.output
      forward_to = [prometheus.relabel.integrations_node_exporter.receiver]
    }

    prometheus.relabel "integrations_node_exporter" {
      forward_to = [prometheus.remote_write.metrics_service.receiver]

      rule {
        source_labels = ["__name__"]
        regex         = "node_scrape_collector_.+"
        action        = "drop"
      }
    }

    loki.source.journal "journal" {
      max_age       = "24h0m0s"
      relabel_rules = discovery.relabel.journal.rules
      forward_to    = [loki.write.grafana_cloud_loki.receiver]
    }

    discovery.relabel "journal" {
      targets = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal__boot_id"]
        target_label  = "boot_id"
      }

      rule {
        source_labels = ["__journal__transport"]
        target_label  = "transport"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }
  '';
in
{
  services.alloy = {
    enable = true;
    configPath = alloyConfig;
    environmentFile = config.sops.templates."alloy-env".path;
  };

  # Alloy needs journal access for log shipping
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "systemd-journal" ];

  sops.secrets."grafana_cloud_api_key" = { };

  sops.templates."alloy-env" = {
    content = "GRAFANA_CLOUD_API_KEY=${config.sops.placeholder."grafana_cloud_api_key"}";
  };
}
