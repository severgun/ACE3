#include "script_component.hpp"
/*
 * Author: GitHawk
 * Disconnect a fuel nozzle and make unit pick it up.
 *
 * Arguments:
 * 0: Unit <OBJECT> (default: objNull - drop on floor)
 * 1: Nozzle <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [player, nozzle] call ace_refuel_fnc_disconnect
 *
 * Public: No
 */

params [["_unit", objNull, [objNull]], ["_nozzle", objNull, [objNull]]];

private _sink = _nozzle getVariable [QGVAR(sink), objNull];
if (isNull _sink) exitWith {};

_sink setVariable [QGVAR(nozzle), nil, true];
if (_nozzle isKindOf "Land_CanisterFuel_F") then { _nozzle setVariable [QEGVAR(cargo,canLoad), true, true]; };
_sink setVariable [QEGVAR(cargo,canLoad), true, true];
_nozzle setVariable [QGVAR(sink), nil, true];
_nozzle setVariable [QGVAR(isConnected), false, true];
[objNull, _nozzle, true] call FUNC(dropNozzle);

if (!isNull _unit) then {
    [_unit, _nozzle] call FUNC(takeNozzle);
};
