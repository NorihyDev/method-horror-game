// In-memory token buckets keyed by "<scope>:<subject>". Suitable for a single
// lobby instance; a multi-instance deployment needs a shared store (see docs).

export interface Limit {
  capacity: number;
  perSecond: number;
}

export const LIMITS = {
  guestPerIp: { capacity: 10, perSecond: 10 / 600 },
  createPerUser: { capacity: 5, perSecond: 5 / 600 },
  createPerIp: { capacity: 20, perSecond: 20 / 600 },
  joinPerUser: { capacity: 10, perSecond: 10 / 60 },
  // Shared networks (schools, carriers) put many players behind one IP.
  joinPerIp: { capacity: 60, perSecond: 60 / 60 },
  badCodePerUser: { capacity: 15, perSecond: 15 / 3600 },
  apiPerUser: { capacity: 60, perSecond: 2 },
} satisfies Record<string, Limit>;

interface Bucket {
  tokens: number;
  at: number;
}

export class RateLimiter {
  private buckets = new Map<string, Bucket>();
  private now: () => number;

  constructor(now: () => number = () => Date.now() / 1000) {
    this.now = now;
  }

  /** Consumes one token; returns seconds to wait (0 = allowed). */
  take(key: string, limit: Limit): number {
    const t = this.now();
    const b = this.buckets.get(key) ?? { tokens: limit.capacity, at: t };
    const tokens = Math.min(limit.capacity, b.tokens + (t - b.at) * limit.perSecond);
    if (tokens < 1) {
      this.buckets.set(key, { tokens, at: t });
      return Math.ceil((1 - tokens) / limit.perSecond);
    }
    this.buckets.set(key, { tokens: tokens - 1, at: t });
    return 0;
  }

  /** Checks without consuming. */
  peek(key: string, limit: Limit): boolean {
    const t = this.now();
    const b = this.buckets.get(key);
    if (!b) return true;
    return Math.min(limit.capacity, b.tokens + (t - b.at) * limit.perSecond) >= 1;
  }

  prune(maxIdleSeconds = 7200): void {
    const t = this.now();
    for (const [k, b] of this.buckets) if (t - b.at > maxIdleSeconds) this.buckets.delete(k);
  }
}
