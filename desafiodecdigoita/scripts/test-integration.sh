#!/bin/bash
set -e

echo "🧪 Rodando testes de integração (TestContainers)..."
echo ""

# Verifica se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. TestContainers precisa de Docker."
    exit 1
fi

mvn test -B -Dtest="*IntegrationTest" -DfailIfNoTests=false

echo ""
echo "✅ Testes de integração passaram!"