---
layout: wiki
title: Parachute Framework
description: Explains how to set-up a parachute with ACE3 parachute system.
group: framework
order: 5
parent: wiki
mod: ace
version:
  major: 3
  minor: 2
  patch: 0
---

## 1. Adding reserve parachute to existing parachute

```cpp
class CfgVehicles {
    class ParachuteBase;
    class BananaParachute: ParachuteBase {
        ace_hasReserveParachute = 1;  // Add reserve parachute (1-enabled, 0-disabled)
        ace_reserveParachute = "ACE_ReserveParachute";  // Classname of the reserve parachute
    };
};
```

## 2. Adding failure cut delay

```cpp
class CfgVehicles {
    class ParachuteBase;
    class BananaParachute: ParachuteBase {
        ace_parachute_failureDelay = 2;  // Add delay before parachute fails (time in seconds)
    };
};
```
