#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/ReCord.app"
FINAL_DMG_PATH="$ROOT_DIR/dist/ReCord.dmg"

if [ ! -d "$APP_PATH" ]; then
    "$ROOT_DIR/scripts/build_release_app.sh"
fi

# Clean up
rm -f "$FINAL_DMG_PATH"

# Generate dmgbuild settings with correct paths
cat > /tmp/record_dmg_settings.py << PYEOF
# DMG build settings for ReCord
format = "UDZO"
compression_level = 9
volume_name = "ReCord"
window_rect = ((100, 100), (640, 400))
background_color = (0.11, 0.11, 0.13)
icon_size = 96
text_size = 12
arrangement = "free"
label_position = "bottom"
show_icon_preview = False
show_status_bar = False
show_tab_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0
badge_icon = None
icon_locations = {
    "ReCord.app": (120, 200),
    "Applications": (520, 200),
}
files = ["$APP_PATH"]
symlinks = {"Applications": "/Applications"}
PYEOF

# Build DMG with dmgbuild for precise window layout
echo "Building DMG with dmgbuild..."
python3 -m dmgbuild \
    -s /tmp/record_dmg_settings.py \
    "ReCord" \
    "$FINAL_DMG_PATH"

# Clean up
rm -f /tmp/record_dmg_settings.py

echo "Done: $FINAL_DMG_PATH"
