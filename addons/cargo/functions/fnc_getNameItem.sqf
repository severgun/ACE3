#include "script_component.hpp"
/*
 * Author: JasperRab
 * Gets the name of the item, and alternatively the custom name if requested and available.
 *
 * Arguments:
 * 0: Target <OBJECT>
 * 1: Add custom name part <BOOL> (default: false)
 *
 * Return Value:
 * Item Name <STRING>
 *
 * Example:
 * [crate_7] call ace_cargo_fnc_getNameItem
 *
 * Public: Yes
 */

params ["_object", ["_addCustomPart", false]];

private _displayName = if (_object isEqualType "") then {
    getText (configFile >> "CfgVehicles" >> _object >> "displayName")
} else {
    getText ((configOf _object) >> "displayName")
};

if (_addCustomPart && {!(_object isEqualType "")}) then {
    private _customPart = _object getVariable [QGVAR(customName), ""];

    if (_customPart isNotEqualTo "") then {
        _displayName = _displayName + " [" + _customPart + "]";
    };
};

_displayName
