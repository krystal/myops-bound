# MyOps Bound Module

This module provides support for reverse DNS record syncing with a [Bound](https://github.com/adamcooke/bound) installation. To use this in your MyOps installation just follow the instructions below.

## Installation

Add `myops-bound` plus required configuration to your MyOps configuration file at `/opt/myops/config/myops.yml`.

```yaml
modules:
  -
    name: myops-bound
    config:
      host: dns.example.org
      ssl: true
      api_key: abc123abc123abc123abc
```

Once, you've done this you can update the modules the application and restart it.

```
$ myops update-modules
$ myops restart
```
