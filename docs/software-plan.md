# Nerves Sprinklers — Software Implementation Plan

## Context

The nerves_sprinklers project needs its application layer built from scratch. The hardware is designed and documented. The codebase is currently Nerves boilerplate with no application logic. This plan implements the full software stack: GPIO control, distributed scheduling, persistence, and a Phoenix/LiveView web UI — treating all zones across all controllers as a single unified system.

---

## Architecture Overview

```
Coordinator (Pi 3)                           Worker(s) (Pi Zero W, one or more)
─────────────────────────────────            ──────────────────────────────────
Phoenix/LiveView (web UI)                    (no web UI)
Scheduler GenServer                          
Executor GenServer                           
NodeWatcher GenServer          ←── LAN ───►  
Ecto Repo (SQLite)                           
GpioServer (local zones)                     GpioServer (local zones)
libcluster (Gossip)            ◄── UDP ───►  libcluster (Gossip)
```

All devices run the same codebase. Role (`:coordinator` or `:worker`) is set in each device's config file. Node names are user-defined — no location names are hardcoded. Any number of worker nodes can be deployed.

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Persistence | `ecto_sqlite3` at `/data/sprinklers.db` | Standard for Nerves; survives firmware updates |
| GPIO | `circuits_gpio` v2 | Nerves standard; active-LOW init at startup |
| Cluster formation | `libcluster` Gossip strategy | UDP multicast, zero config, works on same LAN |
| Scheduling engine | Custom GenServer + `timex` | Quantum can't express "every N days from date" |
| Concurrency | One zone at a time, always | Water pressure constraint |
| Conflict detection | At schedule-save time, 28-day lookahead | Prevent invalid schedules before they fail at runtime |
| Timezone | System-wide local timezone config; naive times in DB; UTC only for timer math | All display and input in local time; one timezone for the whole system |
| Web UI | Phoenix + LiveView, coordinator only | Real-time updates via PubSub; started conditionally |
| Authentication | Single shared password; session-based login form; password stored in DB | Runtime-changeable via web UI. PBKDF2 hashing via OTP stdlib `:crypto.pbkdf2_hmac/5` — no extra dep. First-boot `/setup` flow creates the initial password. |
| Node identity | Two firmware builds from device-specific config files | Simplest for a fixed two-device system |
| Zone configuration | Managed in DB via web UI | Add/remove zones at runtime without firmware rebuild |
| GPIO pin awareness | `/data/relay_pins.dat` per-node persistent file; updated by web UI | Survives firmware updates; no reflash needed to add relay channels. GpioServer reads file at boot and accepts live add/remove messages. |
| GPIO auto-detection | Not feasible | Relay inputs are passive (optocoupler); no electrical feedback to Pi. User enters BCM pin number in zone UI; "test" button clicks relay to verify. |

---

## Data Model

### Schemas

**`zones`** — Managed via web UI; created/edited/deleted at runtime
- `number` (unique), `name`, `node` (Erlang node name atom, e.g. `:"sprinklers@shed.local"`), `gpio_pin`, `active_low`
- User selects node from a dropdown of all currently connected nodes; enters BCM pin number; no firmware rebuild required

**`zone_groups`** + **`zone_group_members`** (join)
- Groups are labels only; scheduling is per-zone

**`schedules`**
- `name`, `enabled`, `recurrence_type` ("every_n_days" | "days_of_week")
- `recurrence_days` (integer N for every_n_days)
- `recurrence_dow` (JSON array of integers 1–7 for days_of_week)
- `start_date` (naive date), `start_time` (naive time — interpreted in system timezone), `seasonal_offset` (integer %, default 100)
- `paused_until` (naive date, null = not paused)

> All schedule times are stored as naive (no timezone). System timezone is configured once in `config/garage.exs` and `config/basement.exs` (e.g., `timezone: "America/Chicago"`). Timex converts naive local times to UTC only when calculating timer intervals.

**`schedule_zones`** (join with duration)
- `schedule_id`, `zone_id`, `position` (run order), `duration_sec`

**`schedule_runs`** (history — denormalized)
- `schedule_id`, `schedule_name`, `trigger_type`, `scheduled_at`, `started_at`, `completed_at`, `status`

**`zone_runs`** (history — denormalized)
- `schedule_run_id`, `zone_number`, `zone_name`, `planned_duration_sec`, `actual_duration_sec`, `status`

**`settings`** (single-row table)
- `password_hash`, `password_salt` — PBKDF2-SHA256 via `:crypto.pbkdf2_hmac/5`; set via web UI; no plaintext ever stored

**`schedule_snapshots`** (config versioning)
- `schedule_id`, `version`, `snapshot_json` (full schedule state as JSON blob)
- Captured automatically inside an `Ecto.Multi` whenever a schedule is updated

---

## Module Structure

```
lib/nerves_sprinklers/
  config/node_config.ex          # role detection, zone ownership lookup
  repo.ex                        # Ecto.Repo (coordinator only)
  schema/                        # all Ecto schemas + changesets
  context/
    zones.ex                     # Zone + ZoneGroup CRUD
    schedules.ex                 # Schedule CRUD + snapshot capture + conflict check
    history.ex                   # query functions for run history
    auth.ex                      # set_password/1, verify_password/1, password_set?/0 — PBKDF2 via :crypto
  scheduler/
    scheduler.ex                 # GenServer: next-run timers, fires Executor
    recurrence.ex                # pure: calculates next run date from recurrence config
    conflict_checker.ex          # pure: 28-day lookahead overlap detection
  executor/
    executor.ex                  # GenServer: sequential zone run, timer, history recording
    zone_driver.ex               # routes activate/deactivate to local or remote GpioServer
  gpio/
    gpio_server.ex               # GenServer: owns circuits_gpio refs; inits relay_pins HIGH at start; open/close by pin number
  cluster/
    node_watcher.ex              # monitors all worker nodes up/down; maintains connected-worker set; notifies Executor + PubSub

lib/nerves_sprinklers_web/
  endpoint.ex, router.ex
  auth.ex                        # on_mount hook: checks session; redirects to /setup if no password set, /login if not authenticated
  live/
    setup_live.ex                # first-boot password creation (public route, only accessible when no password is set)
    login_live.ex                # login form — calls Auth.verify_password/1, sets session on success
    settings_live.ex             # change password form (authenticated)
    dashboard_live.ex            # real-time zone status, manual controls, upcoming runs
    zones_live.ex                # zone + group management
    schedule_live/{index,form,show}.ex
    history_live.ex              # paginated run history

priv/repo/migrations/            # 001–007 (zones, groups, schedules, etc.)
```

---

## Supervisor Tree

```
NervesSprinklers.Application
  ├── Cluster.Supervisor (libcluster, both nodes)
  ├── GpioServer (both nodes — initializes relay_pins HIGH on start)
  └── [coordinator_children if role == :coordinator]
        ├── NervesSprinklers.Repo
        ├── Ecto.Migrator (runs migrations at boot)
        ├── NervesSprinklers.Cluster.NodeWatcher
        ├── NervesSprinklers.Executor.Executor
        ├── NervesSprinklers.Scheduler.Scheduler
        └── NervesSprinklersWeb.Endpoint
```

---

## Key GenServer Designs

### GpioServer (both nodes)
- On `init/1`: reads `/data/relay_pins.dat` (persisted Erlang binary term); opens each listed pin HIGH (relay off). If file absent (first boot), starts with empty pin set — safe because no zones exist yet.
- Messages: `{:open_pin, pin}`, `{:close_pin, pin}`, `:close_all`, `:get_state`
- Live pin management (no restart needed): `{:add_pin, pin}` — opens pin HIGH, adds to tracked set, rewrites file; `{:remove_pin, pin}` — sets pin HIGH, removes from tracked set, rewrites file
- Registered by name; remote node accesses via `GenServer.call({GpioServer, :"sprinklers@basement.local"}, msg)`
- All pin knowledge comes from `/data/relay_pins.dat`; no pin lists in device config

### ZoneDriver (coordinator)
- Receives a zone struct (with `node` and `gpio_pin` from DB)
- Routes: if `zone.node == node()` → local GpioServer; else `GenServer.call({GpioServer, remote_node}, {:open_pin, zone.gpio_pin}, 5_000)`

### Executor (coordinator)
- Holds: `status` (:idle/:running), `current_run` (zone queue + timer_ref), `queue`
- Sequential flow: activate zone → start timer → `zone_timer_expired` → deactivate → next zone
- Calls `ZoneDriver` which routes to local or remote GpioServer
- Records `schedule_runs` and `zone_runs` rows; broadcasts PubSub events for LiveView
- On `terminate/2`: calls `GpioServer.close_all/0` (safety — no stuck relays on crash/restart)

### Scheduler (coordinator)
- On start and after any schedule change: calculates next run time per schedule, sets `send_after` timers
- `{:schedule_timer_fired, id}`: checks not paused/disabled, calls `Executor.start_run/2`, recalculates next timer
- `{:pause_schedule, id, days}`: sets `paused_until` in DB, cancels run timer, sets pause-expiry timer
- Handles `:time_offset` VM messages (NTP clock sync on boot may jump clock)

### Web Authentication
- Password stored in the `settings` DB table as a PBKDF2-SHA256 hash + salt; changeable at runtime via web UI; no plaintext ever persisted
- Hashing: `:crypto.pbkdf2_hmac(:sha256, password, salt, 200_000, 32)` — OTP stdlib, no extra dependency
- `NervesSprinklers.Auth` context: `set_password/1`, `verify_password/1`, `password_set?/0`
- `SetupLive` at `/setup`: first-boot flow; only accessible when `password_set?/0` is false; redirects to `/login` once password is created
- `LoginLive` at `/login`: password form; calls `Auth.verify_password/1`, sets `authenticated: true` in Phoenix session on match
- `SettingsLive`: authenticated page for changing the password
- `NervesSprinklersWeb.Auth` `on_mount` hook:
  - No password set → redirect to `/setup`
  - Password set, not authenticated → redirect to `/login`
  - Authenticated → allow
- Router: `/setup` and `/login` in a public pipeline; all other live routes attach the `Auth` hook
- Logout: clear the session; link in nav

### Conflict Checker (pure module)
```
check_conflicts(candidate_schedule, existing_schedules) :: :ok | {:conflict, details}

Algorithm:
  For each day in 28-day lookahead window:
    Find all schedules (including candidate) that run on this day
    For each pair sharing at least one zone:
      Compute run windows: [start_time, start_time + Σ(duration * seasonal_offset/100)]
      If windows overlap → conflict
```

---

## Distributed Erlang Setup

- **One firmware build per device** — each device gets its own config file with a user-chosen node name:

  `config/coordinator.exs` (coordinator device):
  ```elixir
  config :nerves_sprinklers,
    role: :coordinator,
    node_name: :"sprinklers@myhome.local",   # user-defined
    timezone: "America/Chicago"
  ```

  `config/worker_shed.exs` (example worker — name is up to the user):
  ```elixir
  config :nerves_sprinklers,
    role: :worker,
    node_name: :"sprinklers@shed.local",     # user-defined
    timezone: "America/Chicago"
  ```

  Any number of worker devices can be deployed. Each gets its own config file with a unique node name. No location names are hardcoded in the application.

  Each device stores its relay pin list in `/data/relay_pins.dat` (persistent Erlang binary term on the `/data` partition, survives firmware updates). GpioServer reads this at boot and drives all listed pins HIGH. The web UI writes this file when zones are created or deleted, and notifies GpioServer live — no reflash or restart needed.

  - Built with e.g.: `mix firmware --target rpi3 MIX_TARGET_CONFIG=coordinator`
  - `rel/vm.args.eex` sets `-name` from build-time config
- `libcluster` Gossip on UDP multicast `230.1.1.1:45892`, TTL 1 (LAN only) — automatically discovers all nodes
- Shared cookie: in `mix.exs` release config (same codebase = same cookie)
- mDNS hostnames set per-device via `mdns_lite` from the node name in device config
- NodeWatcher uses `:net_kernel.monitor_nodes/1` to track all connected worker nodes as a set; notifies Executor and PubSub on connect/disconnect
- `ZoneDriver` routes: if `zone.node == node()` → local call; else `GenServer.call({GpioServer, zone.node}, msg, 5_000)` — works for any worker node
- Worker offline during a run: call times out → Executor catches → abort that zone, log error, continue with remaining zones on other nodes

---

## Dependencies to Add (mix.exs)

```elixir
{:ecto_sqlite3, "~> 0.18"},
{:phoenix, "~> 1.8"},
{:phoenix_live_view, "~> 1.0"},
{:phoenix_html, "~> 4.0"},
{:plug_cowboy, "~> 2.7"},
{:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
{:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
{:circuits_gpio, "~> 2.1", targets: @all_targets},
{:libcluster, "~> 3.3"},
{:timex, "~> 3.7"},
{:telemetry_metrics, "~> 1.0"},
{:telemetry_poller, "~> 1.0"},
```

---

## Critical Files

- `mix.exs` — add deps, configure `@all_targets`
- `lib/nerves_sprinklers/application.ex` — supervisor tree with role branching
- `config/coordinator.exs` — coordinator role, node name, timezone (template; user sets node_name)
- `config/worker_<name>.exs` — worker role, node name, timezone (one per worker device; user-named)
- `/data/relay_pins.dat` — per-node persistent file (written at runtime by web UI, not in the repo)
- `config/target.exs` — shared target config: libcluster topology, Phoenix endpoint base config
- `config/host.exs` — Ecto sandbox, mock GPIO, dev overrides
- `rel/vm.args.eex` — sets `-name` from build-time config

---

## Phased Implementation Order

### Phase 0 — Foundation + Web Shell
*Goal: GPIO works and a browser opens to a dashboard on first deploy.*

1. Update `mix.exs` with all new deps
2. Add device configs (`garage.exs`, `basement.exs`) and libcluster to supervisor
3. Implement `NodeConfig` (role detection)
4. Implement `GpioServer` (reads `relay_pins` from config, drives all pins HIGH at start; open/close by pin number)
5. Implement `ZoneDriver` (local vs remote routing by pin number)
6. Add Phoenix to supervisor (coordinator only), configure endpoint
7. `router.ex` + layout shells + Tailwind + esbuild in firmware asset pipeline
8. `LoginLive` + `Auth` `on_mount` hook — all routes protected except `/login`
9. `DashboardLive` shell — real UI, empty zone list (zones created in Phase 1)

**Testable:** SSH → `NervesSprinklers.GpioServer.open_pin(17)` → garage relay 1 clicks. Browser → `http://garage.local` redirects to `/login`, password accepted, dashboard renders.

---

### Phase 1 — Persistence + Zone/Group UI
*Goal: Zones and schedules fully manageable in the browser.*

1. Add `Repo` + migrations (001–007)
2. Write all Ecto schemas + changesets
3. Implement `Zones` and `Schedules` contexts (CRUD, no scheduling logic yet)
4. Implement `ConflictChecker` with unit tests
5. Wire `DashboardLive` to real zone data from DB
6. `ZonesLive` — zone create/edit/delete; node dropdown shows all currently connected nodes; user enters BCM pin number; on save, coordinator writes to target node's `/data/relay_pins.dat` and sends `{:add_pin}` to that GpioServer; "test" button briefly activates relay to verify wiring
7. Zone groups create/edit
8. `ScheduleLive.Index` + `ScheduleLive.Form` — schedule CRUD with conflict warnings

**Testable:** Create zones via the browser (enter BCM pin number, hear relay click). Create a schedule, see conflict warning on overlap.

---

### Phase 2 — Scheduler + Executor
*Goal: Schedules fire automatically; dashboard shows live run progress.*

1. Implement `Recurrence` module with unit tests (test with known dates)
2. Implement `Executor` GenServer (zone queue, timer, history recording)
3. Implement `Scheduler` GenServer (timer management, fires Executor)
4. Implement `NodeWatcher`
5. Wire PubSub broadcasts to `DashboardLive` — live zone status, active run progress
6. Manual run controls on dashboard become functional
7. `ScheduleLive.Show` — schedule detail with next run time
8. `HistoryLive` — paginated run history

**Testable:** Create schedule for T+1 min in browser → zones fire → dashboard shows live progress → history populated.

---

### Phase 3 — Pause, History, Hardening
*Goal: All user-facing features complete; system is production-ready.*

- Pause/resume UI in schedule management
- Manual skip next run
- Abort current run button (dashboard)
- `HistoryLive` — config snapshot browser (view past schedule versions)
- Power-on safety verification (all pins HIGH before any app logic)
- Clock sync handling (NTP jump on boot)
- Firmware update via SSH; confirm `/data` partition preserved

**Testable:** Unplug garage Pi mid-run → plug back in → no stuck relay → schedule resumes next occurrence.

---

## Extensibility Notes *(future phases — do not implement now)*

- **Weather API**: Hook into `Scheduler`'s "should I run today?" decision as a pluggable behaviour
- **Home Assistant**: Standard HA MQTT integration; `ZoneDriver` interface is the clean boundary
- **Alerting**: Add a `FeedbackServer` that monitors `zone_runs` completion times vs expected; emit telemetry events
- **Mobile app**: Extend Phoenix with JSON endpoints alongside the LiveView routes
