import type { ReactNode } from 'react';

export function Notice({ children, tone = 'info' }: { children: ReactNode; tone?: 'info' | 'warning' | 'success' | 'danger' }) {
  return <div className={`notice notice-${tone}`} role="status">{children}</div>;
}
