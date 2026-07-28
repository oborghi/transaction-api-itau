#!/bin/bash
set -e

echo "📊 Gerando relatório de cobertura..."
echo ""

mvn test jacoco:report -B -Dsurefire.excludes="**/integration/*Test.kt,**/integration/*Test.java"

echo ""
echo "✅ Relatório gerado!"
echo "   Abrir: transaction-api/target/site/jacoco/index.html"
echo ""
echo "📊 Verificando cobertura mínima (80%)..."
mvn jacoco:check -B -Dsurefire.excludes="**/integration/*Test.kt,**/integration/*Test.java"

echo ""
echo "✅ Cobertura >= 80% verificada!"