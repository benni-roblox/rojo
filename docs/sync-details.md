This page aims to describe how Rojo turns files on the filesystem into Roblox objects.

[TOC]

## Overview
| File Name      | Instance Type       |
| -------------- | ------------------- |
| any directory  | `Folder`            |
| `*.server.lua` | `Script`            |
| `*.client.lua` | `LocalScript`       |
| `*.lua`        | `ModuleScript`      |
| `*.csv`        | `LocalizationTable` |
| `*.txt`        | `StringValue`       |
| `*.model.json` | Any                 |
| `*.rbxm`       | Any                 |
| `*.rbxmx`      | Any                 |

## Limitations
Not all property types can be synced by Rojo in real-time due to limitations of the Roblox Studio plugin API. In these cases, you can usually generate a place file and open it when you start working on a project.

Some common cases you might hit are:

* Binary data (Terrain, CSG, CollectionService tags)
* `MeshPart.MeshId`
* `HttpService.HttpEnabled`

For a list of all property types that Rojo can reason about, both when live-syncing and when building place files, look at [rbx_tree's type coverage chart](https://github.com/LPGhatguy/rbx-tree#property-type-coverage).

## Folders
Any directory on the filesystem will turn into a `Folder` instance unless it contains an 'init' script, described below.

## Scripts
The default script type in Rojo projects is `ModuleScript`, since most scripts in well-structued Roblox projects will be modules.

If a directory contains a file named `init.server.lua`, `init.client.lua`, or `init.lua`, that folder will be transformed into a `*Script` instance with the contents of the 'init' file. This can be used to create scripts inside of scripts.

For example, these files:

![Tree of files on disk](images/sync-example-files.svg)
{: align="center" }

Will turn into these instances in Roblox:

![Tree of instances in Roblox](images/sync-example-instances.svg)
{: align="center" }

## Localization Tables
Any CSV files are transformed into `LocalizationTable` instances. Rojo expects these files to follow the same format that Roblox does when importing and exporting localization information.

## Plain Text Files
Plain text files (`.txt`) files are transformed into `StringValue` instances. This is useful for bringing in text data that can be read by scripts at runtime.

## JSON Models
Files ending in `.model.json` can be used to describe simple models. They're designed to be hand-written and are useful for instances like `RemoteEvent`.

A JSON model describing a folder containing a `Part` and a `RemoteEvent` could be described as:

```json
{
    "Name": "My Cool Model",
    "ClassName": "Folder",
    "Children": [
        {
            "Name": "RootPart",
            "ClassName": "Part",
            "Properties": {
                "Size": {
                    "Type": "Vector3",
                    "Value": [4, 4, 4]
                }
            }
        },
        {
            "Name": "SendMoney",
            "ClassName": "RemoteEvent"
        }
    ]
}
```

It would turn into instances in this shape:

![Tree of instances in Roblox](images/sync-example-json-model.svg)
{: align="center" }

## Binary and XML Models
Rojo supports both binary (`.rbxm`) and XML (`.rbxmx`) models generated by Roblox Studio or another tool.

Not all property types are supported for all formats!

For a rundown of supported types, check out [rbx_tree's type coverage chart](https://github.com/LPGhatguy/rbx-tree#property-type-coverage).