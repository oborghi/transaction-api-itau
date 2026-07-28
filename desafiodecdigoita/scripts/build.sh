#!/bin/bash
set -e

echo "🔨 Buildando projeto..."
echo ""

# Verifica Java
if ! java -version 2>&1 | grep -q "21"; then
    echo "❌ Java 21 não encontrado. Instale o JDK 21."
    exit 1
fi

# Verifica Maven
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven não encontrado. Instale o Maven 3.9+."
    exit 1
fi

# Build completo
echo "📦 Executando mvn clean package..."
mvn clean package -B -DskipTests

echo ""
echo "✅ Build concluído com sucesso!"
echo "   JAR: transaction-api/target/*.jar"