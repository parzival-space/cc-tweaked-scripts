# Example
This basic LUA project serves as an example on how to use this project structure.

## Creating your own Project

To create a basic project you just need 2 files:
* [main.lua](./main.lua) - A main script.
* [bundle.json](./bundle.json) - The configuration for the bundler.

### bundle.json

Here you can see what each option stands for:

| Parameter      | Type                                    | Default              | Description                                                                                                                                                                                                                                                                                                                                        |
|----------------|-----------------------------------------|----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| force          | ``boolean``                             | ``false``            | Whether the provided Lua should always be returned as a bundle, even when it required no other modules.                                                                                                                                                                                                                                            |
| isolate        | ``boolean``                             | ``false``            | By default, the bundle is not isolated i.e. at runtime we'll try fallback to regular ``require()`` for modules not included in the bundle.                                                                                                                                                                                                         |
| luaVersion     | ``"5.1" \| "5.2" \| "5.3" \| "LuaJIT"`` | ``5.3``              | Specifies which LUA language version you want to use.                                                                                                                                                                                                                                                                                              |
| metadata       | ``boolean``                             | ``true``             | Unless set to ``false``, the bundle will be encoded with metadata (Lua comments) that describe the specification of the bundle. Unbundling is only possible for bundles that are bundled with metadata. This tool supports the [Lua unbundler](https://github.com/Benjamin-Dobell/luabundler?tab=readme-ov-file#unbundle) made by Benjamin Dobell. |
| main           | ``string``                              | ``main.lua``         | Specifies the entrypoint script.                                                                                                                                                                                                                                                                                                                   |
| rootModuleName | ``string``                              | ``__root``           | The contents of ``main`` are interpreted as module with this name.                                                                                                                                                                                                                                                                                 |
| imports        | ``string[]``                            | ``[ "?", "?.lua" ]`` | The Lua search patterns the bundler should scan. See [Lua Search Patters](https://www.lua.org/pil/8.1.html) for more info.                                                                                                                                                                                                                         |

## Building your Project

Building (or bundling) your Project is as simple as running the according bundler script.
The bundler script accepts currently only one argument wich is also optional.

```bash
./bundler [project_name]
```

If you do not specify the Porject name, all projects will be build.
The resulting files will be placed in the ``dist`` directory, named like the project.
So a project called ``example`` will produce a ``example.lua`` file.