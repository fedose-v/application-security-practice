#!/bin/bash
# Practical Work — Variant 2
# Project: mozilla/pdf.js v3.7.107
# Tool: @cyclonedx/cyclonedx-npm + Trivy
# OS: Linux

set -e

WORKDIR="$(dirname "$0")"
PDFJS_DIR="/tmp/pdfjs-v3.7.107"

echo "===== Step 1: Clone pdf.js v3.7.107 ====="
if [ ! -d "$PDFJS_DIR" ]; then
    git clone --depth 1 --branch v3.7.107 https://github.com/mozilla/pdf.js.git "$PDFJS_DIR"
else
    echo "Already cloned: $PDFJS_DIR"
fi

echo ""
echo "===== Step 2: Install npm dependencies ====="
cd "$PDFJS_DIR"
npm ci --ignore-scripts

echo ""
echo "===== Step 3: Install cyclonedx-npm ====="
npm install -g @cyclonedx/cyclonedx-npm

echo ""
echo "===== Step 4: Generate SBOM (CycloneDX JSON) ====="
cyclonedx-npm --output-format json --output-file "$OLDPWD/sbom.json"
echo "SBOM saved to: sbom.json"
echo "Components count: $(python3 -c "import json; d=json.load(open('$OLDPWD/sbom.json')); print(len(d.get('components', [])))")"

echo ""
echo "===== Step 5: Analyze SBOM with Trivy ====="
trivy sbom "$OLDPWD/sbom.json" --format table 2>&1 | tee "$OLDPWD/trivy-report.txt"

echo ""
echo "===== Step 6: Fix CVE-2023-45133 (update @babel/traverse to 7.23.2) ====="
cd "$PDFJS_DIR"
npm install @babel/traverse@7.23.2 --save-dev

echo ""
echo "===== Step 7: Regenerate SBOM after fix ====="
cyclonedx-npm --output-format json --output-file "$OLDPWD/sbom-updated.json"

echo ""
echo "===== Step 8: Re-analyze updated SBOM with Trivy ====="
trivy sbom "$OLDPWD/sbom-updated.json" --format table 2>&1 | tee "$OLDPWD/trivy-report-updated.txt"

echo ""
echo "===== Done ====="
echo "Artifacts:"
echo "  sbom.json             — initial SBOM"
echo "  trivy-report.txt      — initial Trivy scan"
echo "  sbom-updated.json     — SBOM after fix"
echo "  trivy-report-updated.txt — Trivy scan after fix"
