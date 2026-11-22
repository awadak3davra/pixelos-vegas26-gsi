# Map a patch directory name (platform_frameworks_base) to its tree path (frameworks/base).
tree_of() {
  local t; t="$(tr _ / <<<"$1" | sed -e 's;platform/;;g')"
  case "$t" in
    build) t=build/make ;;
    testing) t=platform_testing ;;
    vendor/hardware/overlay) t=vendor/hardware_overlay ;;
    treble/app) t=treble_app ;;
    vendor/partner/gms) t=vendor/partner_gms ;;
  esac
  echo "$t"
}
