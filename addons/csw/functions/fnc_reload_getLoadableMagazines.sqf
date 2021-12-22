#include "script_component.hpp"
/*
 * Author: PabstMirror
 * Gets magazines that the player is carrying that can be loaded into the static weapon
 *
 * Arguments:
 * 0: Vehicle <OBJECT>
 * 1: Player <OBJECT>
 *
 * Return Value:
 * Mags <ARRAY>
 * [Carry Magazine <STRING>, Turret Path <ARRAY>, Ammo Needed <NUMBER>, Source container <OBJECT>]
 *
 * Example:
 * [cursorObject, player] call ace_csw_fnc_reload_getLoadableMagazines
 *
 * Public: No
 */

params ["_vehicle", "_player"];

private _carriedMagazines = [];
private _magazinesCargo = [];

{
    if (isClass (configFile >> QGVAR(groups) >> _x)) then {
        _carriedMagazines pushBackUnique [_x, _player];
    };
} forEach (magazines _player);

if (_vehicle isKindOf "StaticWeapon") then {
    {
        _x params ["_container"];
        {
            if (isClass (configFile >> QGVAR(groups) >> _x)) then {
                _magazinesCargo pushBackUnique [_x, _container];
            };
        } forEach (magazineCargo _container);
    } forEach (nearestObjects [_vehicle, ["groundWeaponHolder"], 4]);
} else {
    {
        if (isClass (configFile >> QGVAR(groups) >> _x)) then {
            _magazinesCargo pushBackUnique [_x, _vehicle];
        };
    } forEach (magazineCargo _vehicle);
};

TRACE_2("All available magazines:",_carriedMagazines,_magazinesCargo);

_carriedMagazines = _carriedMagazines + _magazinesCargo;

if (_carriedMagazines isEqualTo []) exitWith { [] }; // fast exit if no carry mags

private _loadInfo = [];
private _return = [];
// Go through turrets and find weapons that we could reload
{
    private _turretPath = _x;
    {
        private _weapon = _x;
        {
            _x params ["_carryMag", "_container"];
            private _carryGroup = configFile >> QGVAR(groups) >> _carryMag;
            {
                if (((getNumber (_carryGroup >> _x)) == 1) && {_loadInfo = [_vehicle, _turretPath, _carryMag, _player, _container] call FUNC(reload_canLoadMagazine); _loadInfo select 0}) exitWith {
                    _return pushBack [_carryMag, _turretPath, _loadInfo, _container];
                };
            } forEach ([_weapon] call CBA_fnc_compatibleMagazines);
        } forEach _carriedMagazines;
    } forEach (_vehicle weaponsTurret _turretPath);
} forEach (allTurrets _vehicle);
// Note: these nested forEach's looks terrible, but most only have one element

_return
