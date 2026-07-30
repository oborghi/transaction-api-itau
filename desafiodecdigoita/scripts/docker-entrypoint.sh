#!/bin/sh
set -e

echo "🚀 Transaction API Docker Entrypoint"
echo ""

# ==========================================
# Start the application
# ==========================================
echo ""
echo "🚀 Starting Transaction API..."
echo ""

exec java -cp "app.jar:libs/*" com.itau.transaction.api.TransactionApplicationKt "$@"