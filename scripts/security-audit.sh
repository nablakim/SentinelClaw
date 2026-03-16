#!/bin/bash
# ClawHub Security Audit Script
# Run this script to perform a comprehensive security check

echo "═══════════════════════════════════════════════════════════"
echo "  ClawHub Security Audit Tool"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if running as root (warning)
if [ "$EUID" -eq 0 ]; then 
   echo "⚠️  WARNING: Running as root. Consider using a non-privileged user."
   echo ""
fi

# Run OpenClaw security audit
echo "🔍 Running OpenClaw security audit..."
openclaw security audit

echo ""
echo "───────────────────────────────────────────────────────────"
echo ""

# Check file permissions
echo "🔍 Checking file permissions..."

echo "Credentials directory:"
ls -ld ~/.openclaw/credentials 2>/dev/null || echo "  Not found"

echo ""
echo "Log file:"
ls -l ~/.openclaw/logs/openclaw.log 2>/dev/null || echo "  Not found"

echo ""
echo "───────────────────────────────────────────────────────────"
echo ""

# List installed skills
echo "🔍 Installed ClawHub skills:"
clawhub list 2>/dev/null || echo "  No skills installed or clawhub not configured"

echo ""
echo "───────────────────────────────────────────────────────────"
echo ""

# Check extensions
echo "🔍 Installed extensions:"
ls ~/.openclaw/extensions/ 2>/dev/null | while read ext; do
    echo "  - $ext"
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Audit Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Review any WARN or ERROR messages above"
echo "2. Run 'openclaw security audit --deep' for detailed analysis"
echo "3. Run 'openclaw security audit --fix' to auto-fix issues"
echo "4. Review SECURITY_MEMORY.md for threat intelligence"
echo ""
