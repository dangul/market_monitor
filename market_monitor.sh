#!/bin/bash

# Multi-Index Volatility Monitor with Pushover Notifications
# Monitors VIX, SKEW, and MOVE indexes for market risk assessment

# ============================================
# CONFIGURATION - Edit these values
# ============================================

# Thresholds
VIX_THRESHOLD=30        # S&P 500 Volatility (Fear Index)
SKEW_THRESHOLD=150      # Tail Risk (Crash Warning)
MOVE_THRESHOLD=150      # Bond Market Volatility

# Configuration file location
CONFIG_FILE="./env"

# Log file location
LOG_FILE="./market_monitor.log"

# ============================================
# Do not edit below this line
# ============================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Index definitions
declare -A INDEX_SYMBOLS
INDEX_SYMBOLS[VIX]="^VIX"
INDEX_SYMBOLS[SKEW]="^SKEW"
INDEX_SYMBOLS[MOVE]="^MOVE"

declare -A INDEX_THRESHOLDS
INDEX_THRESHOLDS[VIX]=$VIX_THRESHOLD
INDEX_THRESHOLDS[SKEW]=$SKEW_THRESHOLD
INDEX_THRESHOLDS[MOVE]=$MOVE_THRESHOLD

declare -A INDEX_DESCRIPTIONS
INDEX_DESCRIPTIONS[VIX]="S&P 500 Volatility (Fear Index)"
INDEX_DESCRIPTIONS[SKEW]="Tail Risk Indicator (Crash Warning)"
INDEX_DESCRIPTIONS[MOVE]="Bond Market Volatility"

declare -A ALERT_PRIORITY
ALERT_PRIORITY[VIX]=1       # High priority
ALERT_PRIORITY[SKEW]=2      # Emergency (most important!)
ALERT_PRIORITY[MOVE]=1      # High priority

# Function to load configuration from env file
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}ERROR: Configuration file not found: ${CONFIG_FILE}${NC}"
        echo ""
        echo "Please create the configuration file with:"
        echo "  $0 --create-config"
        echo ""
        echo "Or manually create ${CONFIG_FILE} with:"
        echo "  PUSHOVER_USER_KEY=your_user_key_here"
        echo "  PUSHOVER_API_TOKEN=your_api_token_here"
        return 1
    fi
    
    # Check file permissions (should not be world-readable)
    local perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null)
    if [ ! -z "$perms" ] && [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
        echo -e "${YELLOW}WARNING: Config file has insecure permissions: ${perms}${NC}"
        echo "Setting secure permissions (600)..."
        chmod 600 "$CONFIG_FILE"
    fi
    
    # Source the configuration file
    source "$CONFIG_FILE"
    
    # Validate required variables
    if [ -z "$PUSHOVER_USER_KEY" ] || [ -z "$PUSHOVER_API_TOKEN" ]; then
        echo -e "${RED}ERROR: Missing required configuration${NC}"
        echo "Please ensure ${CONFIG_FILE} contains:"
        echo "  PUSHOVER_USER_KEY=your_user_key_here"
        echo "  PUSHOVER_API_TOKEN=your_api_token_here"
        return 1
    fi
    
    return 0
}

# Function to create configuration file
create_config() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Create Configuration File${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Configuration file already exists: ${CONFIG_FILE}${NC}"
        read -p "Overwrite? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 1
        fi
    fi
    
    echo "Please enter your Pushover credentials:"
    echo "(You can find these at: https://pushover.net)"
    echo ""
    
    read -p "Pushover User Key: " user_key
    read -p "Pushover API Token: " api_token
    
    if [ -z "$user_key" ] || [ -z "$api_token" ]; then
        echo -e "${RED}ERROR: Both User Key and API Token are required${NC}"
        return 1
    fi
    
    # Create config file
    cat > "$CONFIG_FILE" << EOF
# Market Monitor Configuration
# Created: $(date '+%Y-%m-%d %H:%M:%S')

# Pushover credentials
# Get yours at: https://pushover.net
PUSHOVER_USER_KEY=${user_key}
PUSHOVER_API_TOKEN=${api_token}

# Optional: Override thresholds (uncomment to use)
# VIX_THRESHOLD=30
# SKEW_THRESHOLD=150
# MOVE_THRESHOLD=150
EOF
    
    # Set secure permissions
    chmod 600 "$CONFIG_FILE"
    
    echo ""
    echo -e "${GREEN}✓ Configuration file created: ${CONFIG_FILE}${NC}"
    echo -e "${GREEN}✓ Permissions set to 600 (owner read/write only)${NC}"
    echo ""
    echo "You can now test your configuration with:"
    echo "  $0 --test"
    
    return 0
}

# Function to show configuration
show_config() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Current Configuration${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    echo "Config file: ${CONFIG_FILE}"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Status: Not found${NC}"
        echo ""
        echo "Create with: $0 --create-config"
        return 1
    fi
    
    echo -e "Status: ${GREEN}Found${NC}"
    
    local perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null)
    if [ "$perms" = "600" ] || [ "$perms" = "400" ]; then
        echo -e "Permissions: ${GREEN}${perms} (Secure)${NC}"
    else
        echo -e "Permissions: ${YELLOW}${perms} (Insecure - should be 600)${NC}"
    fi
    
    echo ""
    
    if load_config; then
        echo "Pushover User Key: ${PUSHOVER_USER_KEY:0:10}...${PUSHOVER_USER_KEY: -4}"
        echo "Pushover API Token: ${PUSHOVER_API_TOKEN:0:10}...${PUSHOVER_API_TOKEN: -4}"
        echo ""
        echo "Thresholds:"
        echo "  VIX:  > ${VIX_THRESHOLD}"
        echo "  SKEW: > ${SKEW_THRESHOLD}"
        echo "  MOVE: > ${MOVE_THRESHOLD}"
        echo ""
        echo -e "${GREEN}Configuration is valid${NC}"
    else
        echo -e "${RED}Configuration is invalid or incomplete${NC}"
    fi
}

# Function to edit configuration
edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Configuration file not found: ${CONFIG_FILE}${NC}"
        echo "Create it first with: $0 --create-config"
        return 1
    fi
    
    # Detect available editor
    if [ ! -z "$EDITOR" ]; then
        $EDITOR "$CONFIG_FILE"
    elif command -v nano &> /dev/null; then
        nano "$CONFIG_FILE"
    elif command -v vi &> /dev/null; then
        vi "$CONFIG_FILE"
    else
        echo "No text editor found. Please edit manually:"
        echo "  $CONFIG_FILE"
        return 1
    fi
    
    echo ""
    echo "Configuration updated. Test with: $0 --test"
}

# Function to write to log
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} - ${message}" >> "$LOG_FILE"
    
    if [ -t 1 ]; then
        echo -e "${timestamp} - ${message}"
    fi
}

# Function to send Pushover notification
send_pushover() {
    local title="$1"
    local message="$2"
    local url="${4:-}"
    
    local post_data="token=${PUSHOVER_API_TOKEN}&user=${PUSHOVER_USER_KEY}&title=${title}&message=${message}"
    
    if [ ! -z "$url" ]; then
        post_data="${post_data}&url=${url}"
    fi
    
    # For emergency priority (2), add retry and expire parameters
    if [ "$priority" = "2" ]; then
        post_data="${post_data}&retry=60&expire=3600"
    fi
    
    local response=$(curl -s -X POST https://api.pushover.net/1/messages.json \
        -d "$post_data" 2>&1)
    
    if echo "$response" | grep -q '"status":1'; then
        log_message "Pushover notification sent: $title"
        return 0
    else
        log_message "ERROR: Failed to send Pushover notification: $response"
        return 1
    fi
}

# Function to fetch index value
get_index_value() {
    local symbol="$1"
    local index_value=""
    
    # Method 1: Yahoo Finance API v7
    index_value=$(curl -s -A "Mozilla/5.0" --max-time 10 \
        "https://query1.finance.yahoo.com/v7/finance/quote?symbols=${symbol}" \
        | grep -o '"regularMarketPrice":[0-9.]*' \
        | head -1 \
        | cut -d: -f2)
    
    if [ ! -z "$index_value" ] && [ "$index_value" != "null" ]; then
        echo "$index_value"
        return 0
    fi
    
    # Method 2: Yahoo Finance Chart API
    index_value=$(curl -s -A "Mozilla/5.0" --max-time 10 \
        "https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=1d" \
        | grep -o '"regularMarketPrice":[0-9.]*' \
        | head -1 \
        | cut -d: -f2)
    
    if [ ! -z "$index_value" ] && [ "$index_value" != "null" ]; then
        echo "$index_value"
        return 0
    fi
    
    # Method 3: Alternative API endpoint
    index_value=$(curl -s -A "Mozilla/5.0" --max-time 10 \
        "https://query2.finance.yahoo.com/v7/finance/quote?symbols=${symbol}" \
        | grep -o '"regularMarketPrice":[0-9.]*' \
        | head -1 \
        | cut -d: -f2)
    
    if [ ! -z "$index_value" ] && [ "$index_value" != "null" ]; then
        echo "$index_value"
        return 0
    fi
    
    echo "ERROR"
    return 1
}

# Function to compare float values (bash doesn't support float comparison)
compare_float() {
    local value=$1
    local threshold=$2
    awk -v val="$value" -v thr="$threshold" 'BEGIN { if (val > thr) exit 0; else exit 1 }'
}

# Function to check single index
check_index() {
    local index_name="$1"
    local symbol="${INDEX_SYMBOLS[$index_name]}"
    local threshold="${INDEX_THRESHOLDS[$index_name]}"
    local description="${INDEX_DESCRIPTIONS[$index_name]}"
    local priority="${ALERT_PRIORITY[$index_name]}"
    
    log_message "Checking ${index_name} (${symbol})..."
    
    local value=$(get_index_value "$symbol")
    
    if [ "$value" = "ERROR" ]; then
        log_message "${RED}ERROR: Failed to fetch ${index_name} data${NC}"
        return 1
    fi
    
    log_message "${index_name}: ${value} (Threshold: ${threshold})"
    
    # Check if threshold exceeded
    if compare_float "$value" "$threshold"; then
        local alert_title="⚠️ ${index_name} ALERT!"
        local alert_message="${index_name}: ${value}
Threshold: ${threshold}
${description}

Time: $(date '+%Y-%m-%d %H:%M:%S')"
        
        log_message "${RED}ALERT: ${index_name} = ${value} (exceeds ${threshold})${NC}"
        send_pushover "$alert_title" "$alert_message" "$priority" "https://finance.yahoo.com/quote/${symbol}"
        return 2
    else
        log_message "${GREEN}${index_name} = ${value} (Normal - below ${threshold})${NC}"
        return 0
    fi
}

# Function to calculate risk score
calculate_risk_score() {
    local vix_value="$1"
    local skew_value="$2"
    local move_value="$3"
    
    local score=0
    
    # VIX scoring (0-40 points)
    if compare_float "$vix_value" "40"; then
        score=$((score + 40))
    elif compare_float "$vix_value" "30"; then
        score=$((score + 30))
    elif compare_float "$vix_value" "20"; then
        score=$((score + 15))
    fi
    
    # SKEW scoring (0-40 points) - Most important!
    if compare_float "$skew_value" "160"; then
        score=$((score + 40))
    elif compare_float "$skew_value" "150"; then
        score=$((score + 30))
    elif compare_float "$skew_value" "140"; then
        score=$((score + 15))
    fi
    
    # MOVE scoring (0-20 points)
    if compare_float "$move_value" "180"; then
        score=$((score + 20))
    elif compare_float "$move_value" "150"; then
        score=$((score + 15))
    elif compare_float "$move_value" "120"; then
        score=$((score + 8))
    fi
    
    echo $score
}

# Function to get risk level description
get_risk_level() {
    local score=$1
    
    if [ $score -ge 80 ]; then
        echo "🔴 EXTREME RISK"
    elif [ $score -ge 60 ]; then
        echo "🟠 HIGH RISK"
    elif [ $score -ge 40 ]; then
        echo "🟡 ELEVATED RISK"
    elif [ $score -ge 20 ]; then
        echo "🟢 MODERATE RISK"
    else
        echo "✅ LOW RISK"
    fi
}

# Main monitoring function
monitor_indexes() {
    # Load configuration
    if ! load_config; then
        exit 1
    fi
    
    log_message "========================================="
    log_message "Market Volatility Monitor - Starting Check"
    log_message "========================================="
    
    local alert_count=0
    declare -A index_values
    
    # Check all indexes
    for index_name in VIX SKEW MOVE; do
        check_index "$index_name"
        local result=$?
        
        if [ $result -eq 2 ]; then
            alert_count=$((alert_count + 1))
        fi
        
        # Store value for risk calculation
        local value=$(get_index_value "${INDEX_SYMBOLS[$index_name]}")
        index_values[$index_name]=$value
        
        sleep 2  # Avoid rate limiting
    done
    
    # Calculate overall risk score
    if [ "${index_values[VIX]}" != "ERROR" ] && \
       [ "${index_values[SKEW]}" != "ERROR" ] && \
       [ "${index_values[MOVE]}" != "ERROR" ]; then
        
        local risk_score=$(calculate_risk_score "${index_values[VIX]}" "${index_values[SKEW]}" "${index_values[MOVE]}")
        local risk_level=$(get_risk_level $risk_score)
        
        log_message "========================================="
        log_message "Risk Score: ${risk_score}/100"
        log_message "Risk Level: ${risk_level}"
        log_message "========================================="
        
        # Send summary notification if any alerts or high risk
        if [ $alert_count -gt 0 ] || [ $risk_score -ge 60 ]; then
            local summary_priority=0
            if [ $risk_score -ge 80 ]; then
                summary_priority=2  # Emergency
            elif [ $risk_score -ge 60 ]; then
                summary_priority=1  # High
            fi
            
            local summary_message="Risk Score: ${risk_score}/100
${risk_level}

VIX: ${index_values[VIX]} (${VIX_THRESHOLD})
SKEW: ${index_values[SKEW]} (${SKEW_THRESHOLD})
MOVE: ${index_values[MOVE]} (${MOVE_THRESHOLD})

Alerts triggered: ${alert_count}"
            
            send_pushover "📊 Market Risk Summary" "$summary_message" "$summary_priority"
        fi
    fi
    
    log_message "Check completed - ${alert_count} alert(s) triggered"
    log_message ""
}

# Function to show current status
show_status() {
    # Load configuration (but don't exit if it fails)
    load_config > /dev/null 2>&1
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Market Volatility Monitor - Current Status${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    for index_name in VIX SKEW MOVE; do
        local symbol="${INDEX_SYMBOLS[$index_name]}"
        local threshold="${INDEX_THRESHOLDS[$index_name]}"
        local description="${INDEX_DESCRIPTIONS[$index_name]}"
        
        echo -e "${YELLOW}${index_name}${NC} (${symbol})"
        echo "  Description: ${description}"
        echo "  Threshold: ${threshold}"
        
        local value=$(get_index_value "$symbol")
        if [ "$value" != "ERROR" ]; then
            if compare_float "$value" "$threshold"; then
                echo -e "  Current: ${RED}${value} ⚠️ ALERT!${NC}"
            else
                echo -e "  Current: ${GREEN}${value} ✓${NC}"
            fi
        else
            echo -e "  Current: ${RED}ERROR fetching data${NC}"
        fi
        echo ""
    done
}

# Function to test configuration
test_configuration() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Testing Configuration${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    # Check config file
    echo "1. Checking configuration file..."
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}✗ Configuration file NOT found: ${CONFIG_FILE}${NC}"
        echo "  Create with: $0 --create-config"
        return 1
    else
        echo -e "${GREEN}✓ Configuration file found${NC}"
    fi
    
    local perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null)
    if [ "$perms" = "600" ] || [ "$perms" = "400" ]; then
        echo -e "${GREEN}✓ File permissions secure (${perms})${NC}"
    else
        echo -e "${YELLOW}⚠ File permissions: ${perms} (should be 600)${NC}"
    fi
    echo ""
    
    # Load and validate config
    echo "2. Loading configuration..."
    if ! load_config; then
        return 1
    fi
    echo -e "${GREEN}✓ Configuration loaded successfully${NC}"
    echo ""
    
    # Check curl
    echo "3. Checking curl availability..."
    if command -v curl &> /dev/null; then
        echo -e "${GREEN}✓ curl is installed${NC}"
    else
        echo -e "${RED}✗ curl is NOT installed${NC}"
        echo "  Install with: sudo apt-get install curl"
        return 1
    fi
    echo ""
    
    # Test data fetching
    echo "4. Testing data fetch for each index..."
    for index_name in VIX SKEW MOVE; do
        local symbol="${INDEX_SYMBOLS[$index_name]}"
        echo -n "  ${index_name} (${symbol})... "
        local value=$(get_index_value "$symbol")
        if [ "$value" != "ERROR" ]; then
            echo -e "${GREEN}✓ ${value}${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    done
    echo ""
    
    # Test Pushover
    echo "5. Testing Pushover notification..."
    if send_pushover "Test Notification" "Market monitor test - all systems operational!" 0; then
        echo -e "${GREEN}✓ Pushover test notification sent${NC}"
        echo "  Check your device for the notification"
    else
        echo -e "${RED}✗ Failed to send Pushover notification${NC}"
    fi
    echo ""
    
    # Show thresholds
    echo "6. Current alert thresholds:"
    echo "  VIX:  > ${VIX_THRESHOLD}"
    echo "  SKEW: > ${SKEW_THRESHOLD}"
    echo "  MOVE: > ${MOVE_THRESHOLD}"
    echo ""
    
    echo -e "${GREEN}Configuration test complete!${NC}"
}

# Function to show help
show_help() {
    cat << EOF
Market Volatility Monitor - Multi-Index Alert System

DESCRIPTION:
    Monitors VIX, SKEW, and MOVE indexes for market risk assessment.
    Sends Pushover notifications when thresholds are exceeded.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -m, --monitor           Run monitoring check (default)
    -s, --status            Show current index values
    -t, --test              Test configuration and send test notification
    -c, --create-config     Create configuration file
    --show-config           Show current configuration
    --edit-config           Edit configuration file
    -h, --help              Show this help message

CONFIGURATION:
    Configuration file: ${CONFIG_FILE}
    
    Create the config file with:
        $0 --create-config
    
    Or manually create it with:
        PUSHOVER_USER_KEY=your_user_key_here
        PUSHOVER_API_TOKEN=your_api_token_here

INDEXES MONITORED:
    VIX  (^VIX)  - S&P 500 Volatility (Fear Index)
                   Threshold: ${VIX_THRESHOLD}
                   
    SKEW (^SKEW) - Tail Risk Indicator (Crash Warning) ⚠️ CRITICAL
                   Threshold: ${SKEW_THRESHOLD}
                   
    MOVE (^MOVE) - Bond Market Volatility
                   Threshold: ${MOVE_THRESHOLD}

CRON SETUP:
    # Check every 2 hours, 08:00-17:00, weekdays
    0 8-17/2 * * 1-5 /path/to/market_monitor.sh

    # Check every 30 minutes during market hours
    */30 9-16 * * 1-5 /path/to/market_monitor.sh

RISK SCORING:
    0-20:   Low Risk ✅
    20-40:  Moderate Risk 🟢
    40-60:  Elevated Risk 🟡
    60-80:  High Risk 🟠
    80-100: Extreme Risk 🔴

EXAMPLES:
    # Create configuration file
    $0 --create-config
    
    # Test configuration
    $0 --test
    
    # Run monitoring check
    $0 --monitor
    
    # Check current status
    $0 --status

LOG FILE:
    ${LOG_FILE}

For more information: https://pushover.net/api

EOF
}

# Main script logic
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -s|--status)
        show_status
        exit 0
        ;;
    -t|--test)
        test_configuration
        exit 0
        ;;
    -c|--create-config)
        create_config
        exit 0
        ;;
    --show-config)
        show_config
        exit 0
        ;;
    --edit-config)
        edit_config
        exit 0
        ;;
    -m|--monitor|"")
        monitor_indexes
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
