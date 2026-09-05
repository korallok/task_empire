# City building sprites

Place transparent Blender renders in this directory. The Flutter renderer
discovers PNG and WebP files from the asset manifest and automatically replaces
the vector fallback building.

Supported names:

```text
market_level_1.png
market_level_2.png
market_level_3.png
town_hall_level_1.png
town_hall_level_2.png
town_hall_level_3.png
house_level_1.png
library_level_1.png
workshop_level_1.png
tower_level_1.png
garden_level_1.png
```

Lossless `.webp` files with the same stems take priority over `.png`.

Every render must:

- use a square transparent canvas;
- share the same orthographic camera and light direction;
- keep the building base at the same pixel anchor;
- keep the logical footprint aligned to the shared Blender unit grid;
- include consistent transparent padding;
- include its soft ground shadow.

See `docs/blender_asset_pipeline.md` and
`tool/blender/export_city_assets.py`.
