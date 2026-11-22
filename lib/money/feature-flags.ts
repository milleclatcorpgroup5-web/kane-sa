/**
 * Verrou sekirite pou tout mouvman lajan ekstèn.
 * Sa pa li env vars: okenn sekrè oswa konfigirasyon Cloudflare pa ka aktive li.
 * Yon nouvo migration + chanjman kòd revize nesesè pou ouvri mòd sa a pita.
 */
export const MONEY_RAIL_LOCK = Object.freeze({
  realMoneyEnabled: false,
  inboundEnabled: false,
  outboundEnabled: false,
  sandboxEnabled: false,
  killSwitch: true,
  release: 'v1.7.0-dev.0',
} as const);

export function getMoneyRailFlags() {
  return MONEY_RAIL_LOCK;
}

export function isRealMoneyEnabled(): false {
  return false;
}

export function isProviderExecutionEnabled(): false {
  return false;
}
