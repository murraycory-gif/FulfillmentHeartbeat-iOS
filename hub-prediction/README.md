# HUB Prediction

iPhone-first desk for Kalshi 15-minute BTC Up/Down (`KXBTC15M`). One page: sticky call, Kalshi tape, trend chart, roulette, rest-of-day table, optional API trading.

```bash
cd hub-prediction
npm install
npx playwright install chromium
npm run dev
```

Open `http://localhost:8080` at 390×844 (Grok webview / iPhone Safari).

```bash
npm test          # forecast + sizing
npm run qc        # Playwright iPhone QC
```

Quote path is Kalshi open markets + BRTI (Coinbase fallback). Candles, last week, and settled 24 warm in the background. No splash, no second Tape page, no Google fonts.
