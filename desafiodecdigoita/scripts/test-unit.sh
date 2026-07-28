#!/bin/bash
set -e

echo "🧪 Rodando testes unitários..."
echo ""

mvn test -B -Dsurefire.excludes="**/integration/*Test.kt,**/integration/*Test.java" -DfailIfNoTests=false

echo ""
echo "✅ Testes unitários passaram!"