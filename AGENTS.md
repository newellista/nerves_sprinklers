# AGENTS.md — nerves_sprinklers

## What This Is

A Nerves/Elixir sprinkler controller that can run on a single Raspberry Pi or scale out to a coordinator plus any number of workers over a LAN. The coordinator runs the web UI, database, scheduler, and executor. Workers run only GPIO. All devices run the **same codebase** — role is determined at build time via a device config file.

## Tech Stack

- **Elixir ~> 1.19 / OTP 28**, Nerves ~> 1.13
- **Phoenix ~> 1.8 + LiveView ~> 1.0** (coordinator only)
- **SQLite** via `ecto_sqlite3`, at `/data/sprinklers.db` on device
- **circuits_gpio ~> 2.1** (target only — not available on `:host`)
- **libcluster ~> 3.3** — Gossip strategy over UDP multicast `230.1.1.1:45892`
- **timex ~> 3.7** — scheduling math and timezone conversion
- **Tailwind + esbuild** for assets

## Hardware Context

The current deployment uses:
- **Coordinator**: Pi 3, garage, zones 1–10, node name `sprinklers@nerves.local`, GPIO pins 17 27 22 23 24 25 5 6 16 26
- **Worker**: Pi Zero W, basement, zones 11–12, node name `sprinklers@nerves-worker.local`, GPIO pins 17 27

The system supports any number of workers (including zero — coordinator-only is valid). Each worker gets its own config file with a unique node name; no location names are hardcoded in the application.

- Relays are **active-LOW** — all pins driven HIGH at startup (relays off)
- 24VAC transformer powers solenoids; 5V supply powers relay boards
- Relay pin lists persisted to `/data/relay_pins.dat` per node (survives firmware updates)

## Current State — Phase 1 Complete

Phase 0 implemented:
- `GpioServer` GenServer (reads `/data/relay_pins.dat`, drives pins HIGH, handles `{:open_pin}` / `{:close_pin}` / `{:add_pin}` / `{:remove_pin}`)
- `ZoneDriver` (routes GPIO calls to local or remote GpioServer by zone.node)
- `NodeConfig` (role/node name/timezone from config)
- `Auth` context (PBKDF2-SHA256 password hashing via `:crypto.pbkdf2_hmac/5`, no extra dep)
- Phoenix web shell: `SetupLive`, `DashboardLive` (empty), `SettingsLive`
- Session-based auth with `on_mount` hook; `/setup` on first boot, `/login` thereafter
- libcluster Gossip clustering
- CI: GitHub Actions (host tests + firmware builds for RPi3/RPi0)

Phase 1 implemented:
- 8 Ecto migrations (`priv/repo/migrations/`) — zones, zone_groups, zone_group_members, schedules, schedule_zones, run history, settings, schedule_snapshots
- All Ecto schemas with changesets (`lib/nerves_sprinklers/schema/`)
- `Zones` context — Zone + ZoneGroup CRUD with best-effort GpioServer side-effects
- `Schedules` context — CRUD with Ecto.Multi version snapshots on every write
- `Auth` — migrated from file-based store to `settings` DB table
- `Recurrence` — pure `runs_on?/2` and `next_run_after/3` calculations
- `ConflictChecker` — 28-day overlap detection across shared zones
- `DashboardLive` — wired to real zone and node data
- `ZonesLive` — zone and group management at `/zones` (CRUD + 2-second test relay)
- `ScheduleLive.Index` — schedule management at `/schedules` (CRUD + conflict detection + zone assignment)

Not yet implemented (Phase 2+):
- `Scheduler`, `Executor`, `NodeWatcher` GenServers
- PubSub live updates in DashboardLive
- Manual run controls
- Run history LiveView
- Schedule detail with next-run time

## Supervisor Tree

```
NervesSprinklers.Application
  ├── Cluster.Supervisor          (all nodes)
  ├── GpioServer                  (all nodes)
  └── [coordinator only]
        ├── Repo
        ├── Ecto.Migrator          (runs at boot — not yet present)
        ├── NodeWatcher            (not yet present)
        ├── Executor               (not yet present)
        ├── Scheduler              (not yet present)
        └── NervesSprinklersWeb.Endpoint
```

## Key File Locations

```
lib/nerves_sprinklers/
  application.ex                  # supervisor tree, role-based branching
  repo.ex
  config/node_config.ex           # coordinator?/0, node_name/0, timezone/0
  context/auth.ex                 # set_password/1, verify_password/1, password_set?/0
  executor/zone_driver.ex         # routes activate/deactivate to local or remote GpioServer
  gpio/gpio_server.ex             # relay pin management

lib/nerves_sprinklers_web/
  router.ex                       # public pipeline + authenticated pipeline
  auth.ex                         # on_mount hook
  live/{setup,dashboard,settings}_live.ex

config/
  config.exs                      # base: selects host.exs or target.exs
  host.exs                        # dev/test: role=:coordinator, SQLite dev db, no mDNS
  target.exs                      # firmware base: RingLogger, networking, libcluster, SSH
  coordinator.exs                 # coordinator role + node name (used at firmware build time)
  worker.exs                      # worker role + node name

rel/vm.args.eex                   # -name from config, heartbeat, multi_time_warp
rootfs_overlay/etc/iex.exs        # MOTD + Toolshed on device IEx
docs/software-plan.md             # authoritative architecture + phased roadmap
docs/wiring.md                    # hardware wiring guide
```

## Commands

```bash
# Install deps and build assets (first time)
mix setup

# Run tests (always on :host target)
mix test

# Full CI check (compile, format, credo strict, security audits, tests)
mix ci

# Build firmware
mix firmware --target rpi3 MIX_TARGET_CONFIG=coordinator   # coordinator
mix firmware --target rpi0 MIX_TARGET_CONFIG=worker        # worker

# Dev server
mix phx.server
```

## Configuration System

- `Mix.target()` selects `host.exs` (laptop/CI) or `target.exs` (device firmware)
- `MIX_TARGET_CONFIG` env var selects `coordinator.exs` or `worker.exs` at firmware build time
- Role is read at runtime via `Application.get_env(:nerves_sprinklers, :role)`
- No location names are hardcoded — node names are user-defined in device config files

## Data Model (Phase 1 — not yet in code)

See `docs/software-plan.md` for full schema details. Tables planned:

- `zones` — number, name, node (atom), gpio_pin, active_low
- `zone_groups` + `zone_group_members`
- `schedules` — recurrence_type ("every_n_days" | "days_of_week"), start_date/time (naive), seasonal_offset %, paused_until
- `schedule_zones` — join with position + duration_sec
- `schedule_runs` + `zone_runs` — denormalized history
- `settings` — single row: password_hash, password_salt
- `schedule_snapshots` — config versioning via Ecto.Multi on schedule update

All times stored as **naive** (no timezone). Timex converts to UTC only for timer math. System timezone configured once in device config.

## Git & PR Workflow

- **Always create a feature branch and git worktree before making code changes** — use the `superpowers:using-git-worktrees` skill
- Never commit directly to `main`
- CI must be green before pushing: `mix ci`
- Run the `pr-summary` skill before creating any PR; use its output as the PR description

## Code Style

- No comments unless the WHY is non-obvious
- No multi-line docstrings
- Full test coverage required for all new and changed modules
- Tests use real dependencies at system boundaries — do not mock internal modules
- `mix format` + `mix credo --strict` enforced in CI

## Documentation

When changing behavior or interfaces, update the relevant docs before opening a PR:

- `docs/software-plan.md` — architecture decisions, module structure, GenServer designs, phased roadmap
- `docs/wiring.md` — hardware wiring, GPIO pin assignments, BOM
- `README.md` — user-facing setup and usage instructions
- `AGENTS.md` — this file; keep the current-state section accurate as phases complete

## GPIO Behavior Note

`circuits_gpio` is a target-only dependency — it is not available when running on `:host`. Any module that calls `circuits_gpio` directly must be unreachable in host/test builds (already the case: `GpioServer` is started on all nodes but GPIO calls are no-ops when pins are empty; Phase 1+ should add a mock/stub boundary if needed for testing GPIO logic).
