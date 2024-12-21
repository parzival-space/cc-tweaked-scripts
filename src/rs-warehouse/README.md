# RS Warehouse
> Integration of Minecolonies and Refined Storage for enhanced automation.

![preview](./.assets/preview.png)

## Dependencies
To run the RS Warehouse script, you will need the following mods:

* CC: Tweaked [[Modrinth](https://modrinth.com/mod/cc-tweaked)]
* Advanced Peripherals [[Modrinth](https://modrinth.com/mod/advancedperipherals), [Curseforge](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals)]
* Minecolonies [[Curseforge](https://www.curseforge.com/minecraft/mc-mods/minecolonies)]
* Refined Storage [[Modrinth](https://modrinth.com/mod/refined-storage), [Curseforge](https://www.curseforge.com/minecraft/mc-mods/refined-storage), [GitHub](https://github.com/refinedmods/refinedstorage/releases)]
* Entangled (Optional) [[Modrinth](https://modrinth.com/mod/entangled), [Curseforge](https://www.curseforge.com/minecraft/mc-mods/entangled)]

## Features
* Multi-Monitor Support: Connect and display multiple monitors to track your colony’s requests.
* Autocrafting Scheduling: Automatically schedules crafting tasks when your RS network doesn’t have enough resources to complete a request.
* Smart Tier Selection: Automatically selects the highest-tier items for tools and armor.
* Mod-Item Prioritization: Prioritizes Vanilla items over modded items for crafting.
* Wireless Monitoring: Use a Pocket Computer to wirelessly monitor requests and system status. See [rs-warehouse-pocket](../rs-warehouse-pocket/README.md).
<!--* NBT Support -->

## How to use this Script

### Required Items
![requirements](./.assets/requirements.png)

For this script to work you will need to connect a [RS Bridge](https://docs.advanced-peripherals.de/peripherals/rs_bridge/), a [Colony Integrator](https://docs.advanced-peripherals.de/peripherals/colony_integrator/) and the [Warehouse](https://minecolonies.com/wiki/buildings/warehouse) block of your Minecolonies Warehouse to the Computer.
You can connect the Warehouse using a [Wired Modem](https://tweaked.cc/peripheral/modem.html) or using an [Entangled Block](https://www.curseforge.com/minecraft/mc-mods/entangled).

Optionally, but highly recommended, you can also connect multiple [Monitors](https://tweaked.cc/peripheral/monitor.html) to display the status of all current colony requests.

You can also connect a Wireless / Ender Modem. This will allow you to utilize the [rs-warehouse-pocket](../rs-warehouse-pocket/README.md) script.

> [!IMPORTANT]
> If you are using a **Wired Modem**, ensure that the **RS Bridge** is connected using the same wire.
> The ``exportItemToPeripheral()`` function may fail if the Warehouse is not properly linked.

### Installing the Script
To install the script, run the following command in your terminal:
```craftos
wget https://github.com/parzival-space/cc-tweaked-scripts/releases/latest/download/rs-warehouse.lua startup/rs-warehouse.lua
```
This will download the script to your startup directory and run it upon system startup.

### Configuring the Script
After the script is run for the first time, a configuration file ``rsWarehouse.json`` will be created with the following default settings:
```json
{
    "hostname": "rsWarehouse",
    "updateInterval": 15,
    "use24HourFormat": true
}
```
* **hostname**: The name of your computer. This is only required if you plan to use the [rs-warehouse-pocket](../rs-warehouse-pocket/README.md) script.
* **updateInterval**:  How often the system checks for new item requests (in seconds).
* **use24HourFormat**: Whether to use a 24-hour time format.

You can edit this file to adjust the settings based on your preferences.

## License
This script is licensed under the MIT License. See [LICENSE](./LICENSE) for more details.