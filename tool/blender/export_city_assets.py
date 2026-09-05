"""Export Task Empire building collections as consistent isometric sprites.

Blender collection names must use the ``EXPORT_`` prefix, for example:

    EXPORT_town_hall_level_1
    EXPORT_market_level_1

Run from Blender's Scripting workspace or in background mode:

    blender --background art/task_empire_city.blend \
      --python tool/blender/export_city_assets.py
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import bpy
from mathutils import Vector

EXPORT_PREFIX = "EXPORT_"
CAMERA_NAME = "TaskEmpireCamera"
KEY_LIGHT_NAME = "TaskEmpireKeyLight"
RENDER_SIZE = 1024
CAMERA_LOCATION = Vector((9.5, -9.5, 8.0))
CAMERA_TARGET = Vector((0.0, 0.0, 1.1))
ORTHOGRAPHIC_SCALE = 5.8
BUILDING_CODES = (
    "town_hall",
    "house",
    "library",
    "workshop",
    "market",
    "tower",
    "garden",
)
VALID_ASSET_NAME = re.compile(
    rf"^({'|'.join(BUILDING_CODES)})_level_[1-9][0-9]*$"
)


def find_project_root() -> Path:
    configured_root = os.environ.get("TASK_EMPIRE_PROJECT_ROOT")
    if configured_root:
        return Path(configured_root).expanduser().resolve()

    start = (
        Path(bpy.data.filepath).resolve().parent
        if bpy.data.filepath
        else Path.cwd().resolve()
    )
    for candidate in (start, *start.parents):
        if (candidate / "pubspec.yaml").is_file():
            return candidate
    raise RuntimeError(
        "Task Empire project root was not found. Save the .blend file inside "
        "the project or set TASK_EMPIRE_PROJECT_ROOT."
    )


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def ensure_camera(scene: bpy.types.Scene) -> bpy.types.Object:
    camera = bpy.data.objects.get(CAMERA_NAME)
    if camera is None or camera.type != "CAMERA":
        camera_data = bpy.data.cameras.new(CAMERA_NAME)
        camera = bpy.data.objects.new(CAMERA_NAME, camera_data)
        scene.collection.objects.link(camera)

    camera.location = CAMERA_LOCATION
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ORTHOGRAPHIC_SCALE
    camera.data.lens = 50
    point_at(camera, CAMERA_TARGET)
    scene.camera = camera
    return camera


def ensure_key_light(scene: bpy.types.Scene) -> bpy.types.Object:
    light = bpy.data.objects.get(KEY_LIGHT_NAME)
    if light is None or light.type != "LIGHT":
        light_data = bpy.data.lights.new(KEY_LIGHT_NAME, type="AREA")
        light = bpy.data.objects.new(KEY_LIGHT_NAME, light_data)
        scene.collection.objects.link(light)

    light.location = Vector((-6.0, -7.5, 11.0))
    light.data.energy = 1100
    light.data.shape = "DISK"
    light.data.size = 5.5
    point_at(light, Vector((0.0, 0.0, 0.8)))
    return light


def configure_scene(scene: bpy.types.Scene) -> None:
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"

    scene.render.resolution_x = RENDER_SIZE
    scene.render.resolution_y = RENDER_SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.use_file_extension = True
    scene.render.engine = scene.render.engine

    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.035, 0.055, 0.045)

    ensure_camera(scene)
    ensure_key_light(scene)


def export_collections(scene: bpy.types.Scene, output_dir: Path) -> None:
    export_collections = sorted(
        (
            collection
            for collection in bpy.data.collections
            if collection.name.startswith(EXPORT_PREFIX)
        ),
        key=lambda collection: collection.name,
    )
    if not export_collections:
        raise RuntimeError(
            f"No Blender collections with the {EXPORT_PREFIX!r} prefix were found."
        )

    invalid_names = [
        collection.name
        for collection in export_collections
        if not VALID_ASSET_NAME.fullmatch(
            collection.name.removeprefix(EXPORT_PREFIX).lower()
        )
    ]
    if invalid_names:
        raise RuntimeError(
            "Invalid export collection names: "
            + ", ".join(invalid_names)
            + ". Expected names such as EXPORT_town_hall_level_1."
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    original_visibility = {
        collection.name: collection.hide_render for collection in export_collections
    }

    try:
        for collection in export_collections:
            collection.hide_render = True

        for collection in export_collections:
            collection.hide_render = False
            asset_name = collection.name.removeprefix(EXPORT_PREFIX).lower()
            scene.render.filepath = str(output_dir / f"{asset_name}.png")
            print(f"Rendering {asset_name}...")
            bpy.ops.render.render(write_still=True)
            collection.hide_render = True
    finally:
        for collection in export_collections:
            collection.hide_render = original_visibility[collection.name]


def main() -> None:
    scene = bpy.context.scene
    configure_scene(scene)
    project_root = find_project_root()
    output_dir = project_root / "assets" / "city" / "buildings"
    export_collections(scene, output_dir)
    print(f"Task Empire sprites exported to: {output_dir}")


if __name__ == "__main__":
    main()
