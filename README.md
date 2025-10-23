# Multi-Index Volatility Monitor with Pushover Notifications

Monitors three critical market risk indicators (VIX, SKEW, MOVE) and sends Pushover notifications when danger thresholds are exceeded. \
Key Features:

📊 Monitors 3 Indexes:
- VIX (^VIX) - S&P 500 Volatility / "Fear Index" → Alert at 30 
- SKEW (^SKEW) - Tail Risk / Crash Warning → Alert at 150 ⚠️ Most Important! 
- MOVE (^MOVE) - Bond Market Volatility → Alert at 150 

🔔 Smart Alerting  \
- Priority levels: Normal / High / Emergency (requires acknowledgment)
- Risk scoring: Calculates 0-100 risk score combining all three indexes
- Summary notifications: Overall market risk assessment

🔒 Secure Configuration  
- Credentials stored in ~/.market_monitor.env (not in script)
- Auto-sets secure file permissions (600)
- Validates config on every run

📝 Logging:
- All checks logged to ~/market_monitor.log
- Timestamp for every action
- Error tracking

## Index references

- VIX - CBOE Volatility Index \
🔗 Official CBOE Page: \
https://www.cboe.com/tradable_products/vix/ \
What it is: S&P 500 implied volatility over next 30 days. Known as the "Fear Index" \

- SKEW - CBOE Skew Index \
🔗 Official CBOE Page: \
https://www.cboe.com/tradable_products/vix/volatility_on_stock_indexes/skew_index/ \
What it is: Measures tail risk - probability of extreme negative returns (black swan events) \

- MOVE - ICE BofA MOVE Index \
🔗 Official ICE Page: \
https://fred.stlouisfed.org/series/BAMLMOVE \
What it is: Bond market volatility index - measures expected volatility in U.S. Treasury yields \


## Setup Guide
Interactive setup (recommended) 
```
./market_monitor.sh --create-config 
```
Or manually create ~/.market_monitor.env: 
```
nano ~/.market_monitor.env
```

### Configuration file format (~/.market_monitor.env):
```
# Market Monitor Configuration
# Created: 2024-01-15 10:30:00

# Pushover credentials
# Get yours at: https://pushover.net
PUSHOVER_USER_KEY=uxxxxxxxxxxxxxxxxxxxxxxxxx
PUSHOVER_API_TOKEN=axxxxxxxxxxxxxxxxxxxxxxxxx

# Optional: Override thresholds (uncomment to use)
# VIX_THRESHOLD=30
# SKEW_THRESHOLD=150
# MOVE_THRESHOLD=150
```

### Testing
```
# Show current config
./market_monitor.sh --show-config

# Test configuration (sends test notification)
./market_monitor.sh --test

# Check current market status
./market_monitor.sh --status
```
