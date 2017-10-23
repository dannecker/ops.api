# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :ops, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:ops, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#
# Or read environment variables in runtime (!) as:
#
#     :var_name, "${ENV_VAR_NAME}"
config :ops,
  ecto_repos: [OPS.Repo, OPS.BlockRepo],
  env: Mix.env()

# Configure your database
config :ops, OPS.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: {:system, "DB_NAME", "ops_dev"},
  username: {:system, "DB_USER", "postgres"},
  password: {:system, "DB_PASSWORD", "postgres"},
  hostname: {:system, "DB_HOST", "localhost"},
  port: {:system, :integer, "DB_PORT", 5432}

config :ops, OPS.BlockRepo,
  adapter: Ecto.Adapters.Postgres,
  database: {:system, "BLOCK_DB_NAME", "seed_dev"},
  username: {:system, "BLOCK_DB_USER", "postgres"},
  password: {:system, "BLOCK_DB_PASSWORD", "postgres"},
  hostname: {:system, "BLOCK_DB_HOST", "localhost"},
  port: {:system, :integer, "BLOCK_DB_PORT", 5432}
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration

config :ops,
  namespace: OPS,
  system_user: {:system, "EHEALTH_SYSTEM_USER", "4261eacf-8008-4e62-899f-de1e2f7065f0"}

config :ops, OPS.Scheduler,
  declaration_auto_approve: {:system, :string,
    "DECLARATION_AUTO_APPROVE_SCHEDULE", "* 0-4 * * *"},
  medication_dispense_autotermination: {:system, :string,
    "MEDICATION_DISPENSE_AUTOTERMINATION_SCHEDULE", "* * * * *"},
  medication_dispense_expiration: {:system, :integer, "MEDICATION_DISPENSE_EXPIRATION", 10},
  declaration_autotermination: {:system, :string,
    "DECLARATION_AUTOTERMINATION_SCHEDULE", "* 0-4 * * *"}

# Configures the endpoint
config :ops, OPS.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "4LcL78vtzM1yVeVCuY1351HuU/62qpTtDKykdJxAKKgwnTtH5JzkXNEUouzDBc1D",
  render_errors: [view: EView.Views.PhoenixError, accepts: ~w(json)]

# Configures IL endpoint
config :ops, OPS.API.IL,
  endpoint: {:system, "IL_ENDPOINT", "http://api-svc.il"}, # TODO: update Chart configs
  timeouts: [
    connect_timeout: {:system, :integer, "IL_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "IL_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "IL_REQUEST_TIMEOUT", 30_000}
  ]

config :ops, :declaration_terminator_user,
  {:system, "DECLARATION_TERMINATOR", "48ca528f-0d05-4811-ac49-a249f5309d3e"}

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure JSON Logger back-end
config :logger_json, :backend,
  on_init: {OPS, :load_from_system_env, []},
  json_encoder: Poison,
  metadata: :all

config :ops, OPS.MedicationDispense.Scheduler,
  global: true,
  overlap: false,
  jobs: [
    {
      {
        :cron,
        System.get_env("MEDICATION_DISPENSE_AUTOTERMINATION_SCHEDULE") || "* * * * *"
      },
      {
        OPS.MedicationDispenses,
        :terminate,
        [System.get_env("MEDICATION_DISPENSE_EXPIRATION") || 10]
      }
    },
    {
      {
        :cron,
        System.get_env("MEDICATION_REQUEST_SCHEDULE") || "* * * * *"
      },
      {
        OPS.MedicationRequests,
        :terminate,
        []
      }
    },
    {
      {
        :cron,
        System.get_env("BLOCK_CREATION_SCHEDULE") || "0 0 * * *"
      },
      {
        OPS.Block.API,
        :close_block,
        []
      }
    },
    {
      {
        :cron,
        System.get_env("BLOCK_VALIDATION_SCHEDULE") || "0 5 * * *"
      },
      {
        OPS.Block.API,
        :verify_chain_and_notify,
        []
      }
    }
  ]

config :ops, :block_versions, %{
  "v1" => "
    WITH concat AS (
      SELECT
        ARRAY_TO_STRING(ARRAY_AGG(
          CONCAT(
            id,
            employee_id,
            start_date,
            end_date,
            signed_at,
            created_by,
            scope,
            division_id,
            legal_entity_id,
            inserted_at,
            declaration_request_id,
            person_id,
            seed
          ) ORDER BY id ASC
        ), '') AS value FROM declarations
        WHERE inserted_at > $1 AND inserted_at <= $2
    )
    SELECT digest(concat(value), 'sha512')::text AS value FROM concat
  "
}

# Must be adjusted every time current_block_version is appended with new version
config :ops, :current_block_version, "v1"

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
