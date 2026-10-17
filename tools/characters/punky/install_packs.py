"""Installs MakeHuman asset packs (zips) into MPFB's user data.

blender -b --python install_packs.py -- system.zip skins02.zip hair01.zip
"""
import sys, os, zipfile
from bl_ext.blender_org.mpfb.services.assetservice import AssetService
from bl_ext.blender_org.mpfb.services.locationservice import LocationService
data_dir = LocationService.get_user_data()
packs = sys.argv[sys.argv.index("--") + 1:]
for z in packs:
    bad = AssetService.check_asset_pack_zip(z)
    if bad is None:
        with zipfile.ZipFile(z) as zf:
            zf.extractall(data_dir)
    else:
        res = AssetService.fix_and_extract_asset_pack_zip(z, data_dir)
        print("FIXED", z, res)
AssetService.update_all_asset_lists()
for kind in ["skins", "eyes", "eyebrows", "eyelashes", "hair", "clothes", "proxymeshes", "teeth"]:
    d = os.path.join(data_dir, kind)
    items = sorted(os.listdir(d)) if os.path.isdir(d) else []
    print("ASSETS", kind, len(items), items[:60])
