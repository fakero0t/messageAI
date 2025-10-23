#!/bin/bash

# Simple script to clear definition cache using Firebase CLI
# Usage: ./clearCache.sh [--all|--stats]

PROJECT_ID="messageai-cbd8a"

show_help() {
  echo "Definition Cache Management Tool (Firebase CLI)"
  echo ""
  echo "Usage:"
  echo "  ./clearCache.sh --all     Clear all cached definitions"
  echo "  ./clearCache.sh --stats   Show cache statistics"
  echo "  ./clearCache.sh --help    Show this help"
  echo ""
}

clear_all() {
  echo "🗑️  Clearing ALL definitions from Firestore cache..."
  echo ""
  echo "⚠️  This will delete all documents in the 'definitionCache' collection."
  read -p "Are you sure? (y/N): " -n 1 -r
  echo ""
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    firebase firestore:delete definitionCache --recursive --yes --project $PROJECT_ID
    echo "✅ Cache cleared!"
  else
    echo "Cancelled."
  fi
}

show_stats() {
  echo "📊 Fetching cache statistics..."
  echo ""
  
  # Get total count
  firebase firestore:get definitionCache --project $PROJECT_ID --limit 1000 > /tmp/cache_dump.json 2>&1
  
  if [ -f /tmp/cache_dump.json ]; then
    COUNT=$(grep -c "wordKey" /tmp/cache_dump.json || echo "0")
    echo "Total cached definitions: $COUNT"
    echo ""
    echo "Recent definitions:"
    echo "---"
    firebase firestore:get definitionCache --project $PROJECT_ID --limit 10 --order-by metadata.lastUsed --order-desc
    rm /tmp/cache_dump.json
  else
    echo "❌ Could not fetch cache data"
  fi
}

# Main
case "$1" in
  --all)
    clear_all
    ;;
  --stats)
    show_stats
    ;;
  --help|*)
    show_help
    ;;
esac

