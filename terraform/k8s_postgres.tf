resource "kubernetes_secret_v1" "k8s_secret_postgres" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace_v1.k8s_namespace.metadata[0].name

    labels = {
      "app.kubernetes.io/name"    = "postgres"
      "app.kubernetes.io/part-of" = var.project_name
      "managed-by"                = "terraform"
    }
  }

  type = "Opaque"

  data = {
    POSTGRES_DB       = var.k8s_postgres_db
    POSTGRES_USER     = var.k8s_postgres_user
    POSTGRES_PASSWORD = var.k8s_postgres_password
  }
}

resource "kubernetes_service_v1" "k8s_svc_postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.k8s_namespace.metadata[0].name

    labels = {
      "app.kubernetes.io/name"    = "postgres"
      "app.kubernetes.io/part-of" = var.project_name
      "managed-by"                = "terraform"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "postgres"
    }

    port {
      name        = "tcp-postgresql"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set_v1" "k8s_sts_postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.k8s_namespace.metadata[0].name

    labels = {
      "app.kubernetes.io/name"    = "postgres"
      "app.kubernetes.io/part-of" = var.project_name
      "managed-by"                = "terraform"
    }
  }

  spec {
    service_name = kubernetes_service_v1.k8s_svc_postgres.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "postgres"
          "app.kubernetes.io/part-of" = var.project_name
        }
      }

      spec {
        container {
          name              = "postgres"
          image             = var.k8s_postgres_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "tcp-postgresql"
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.k8s_secret_postgres.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          liveness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }

        volume {
          name = "postgres-data"
          empty_dir {}
        }
      }
    }
  }
}
