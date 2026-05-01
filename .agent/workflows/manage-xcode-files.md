---
description: How to add or remove files from the Xcode project using the ruby script
---

# Managing Xcode Files

When adding or removing Swift files, you must ensure the Xcode project file (`.xcodeproj`) is updated to reflect these changes. We use a Ruby script to automate this.

## Usage

The script `manage_xcode_files.rb` is located in the `scripts` directory of the project.

### Adding Files

To add one or more files to the project:

```bash
ruby scripts/manage_xcode_files.rb add path/to/File1.swift path/to/File2.swift
```

- You can pass multiple file paths.
- The script will add the file to the main target and the appropriate group structure based on the file path.

### Removing Files

To remove one or more files from the project (and optionally delete them from disk):

```bash
ruby scripts/manage_xcode_files.rb remove path/to/File1.swift path/to/File2.swift
```

- **Note**: The script currently removes references from the project. It does *not* delete the file from the filesystem by default, but it's good practice to delete the file using `rm` *before* or *after* running this script if you intend to fully delete it.
- **Best Practice**: Delete the file from the filesystem first, then run the remove command to clean up the project reference.

## Example Workflow (Adding a Service)

1. Create the file:
   ```bash
   touch boringNotch/Plugins/Services/MyNewService.swift
   ```
2. Add to Xcode:
   ```bash
   ruby scripts/manage_xcode_files.rb add boringNotch/Plugins/Services/MyNewService.swift
   ```

## Example Workflow (Removing a Manager)

1. Remove from Xcode:
   ```bash
   ruby scripts/manage_xcode_files.rb remove boringNotch/managers/OldManager.swift
   ```
2. Delete from filesystem:
   ```bash
   rm boringNotch/managers/OldManager.swift
   ```
