# 0005 — Weather provider strategy

- Status: Accepted
- Date: 2026-05-04

## Context

machNotch weather should work reliably while keeping user setup lightweight. OpenWeatherMap is broadly available with API-key configuration, while WeatherKit can be used when available in the Apple ecosystem.

The weather UI should remain ambient, minimal, aesthetic, low-resource, and respectful of Reduce Motion.

## Decision

Use OpenWeatherMap as the primary source in Auto mode, with WeatherKit as fallback when available.

Normal weather fetches should reuse fresh in-memory data for 30 minutes.

## Consequences

- Weather services should avoid unnecessary polling and animation overhead.
- UI should degrade gracefully when one provider is unavailable.
- Provider behavior and cache duration are tracked in `repo.yaml` and implementation details belong in the machNotch PRD/service docs.
