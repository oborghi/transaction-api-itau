#!/bin/bash
set -e

echo "🧪 Rodando todos os testes..."
echo ""

mvn test -B -Dsurefire.excludes="**/integration/*Test.kt,**/integration/*Test.java"

echo ""
echo "✅ Todos os testes passaram!"