#include "script_component.hpp"
/*
 * Author: PabstMirror
 * Loads a magazine into a static weapon from a magazine carried by the player.
 *
 * Arguments:
 * 0: Vehicle <OBJECT>
 * 1: Turret <ARRAY>
 * 2: Unit Carried Magazine <STRING>
 * 3: Player <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [cursorTarget, [0], "ACE_csw_100Rnd_127x99_mag_red", player] call ace_csw_fnc_reload_loadMagazine
 *
 * Public: No
 */

params ["_vehicle", "_turret", "_carryMag", "_unit", "_container"];
TRACE_5("loadMagazine",_vehicle,_turret,_carryMag,_unit,_container);

private _timeToLoad = 1;
if (!isNull(configOf _vehicle >> QUOTE(ADDON) >> "ammoLoadTime")) then {
    _timeToLoad = getNumber(configOf _vehicle >> QUOTE(ADDON) >> "ammoLoadTime");
};

private _displayName = format [localize LSTRING(loadX), getText (configFile >> "CfgMagazines" >> _carryMag >> "displayName")];

private _onFinish = {
    (_this select 0) params ["_vehicle", "_turret", "_carryMag", "_unit", "_container"];
    TRACE_5("load progressBar finish",_vehicle,_turret,_carryMag,_unit,_container);

    ([_vehicle, _turret, _carryMag, _unit, _container] call FUNC(reload_canLoadMagazine)) params ["", "", "_neededAmmo", ""];
    if (_neededAmmo <= 0) exitWith { ERROR_1("Can't load ammo - %1",_this); };

    // Figure out what we can add from the magazines we have
    private _bestAmmoToSend = -1;

    private _magsAmmo = [];
    if (_container == _unit) then {
        _magsAmmo = magazinesAmmo _unit;
    } else {
        _magsAmmo = magazinesAmmoCargo _container;
    };

    {
        _x params ["_xMag", "_xAmmo"];
        if (_xMag == _carryMag) then {
            if ((_bestAmmoToSend == -1) || {(_xAmmo > _bestAmmoToSend) && {_xAmmo <= _neededAmmo}}) then {
                _bestAmmoToSend = _xAmmo;
            };
        };
    } forEach _magsAmmo;

    if (_bestAmmoToSend == -1) exitWith {ERROR_2("No ammo [%1 - %2]?",_xMag,_bestAmmoToSend);};

    if (_container == _unit) then {
    [_unit, _carryMag, _bestAmmoToSend] call EFUNC(common,removeSpecificMagazine);
    } else {
        if (_container isKindOf "groundWeaponHolder") then
        {
            private _magazinesAmmo = magazinesAmmoCargo _container;
            private _count = 1;

            // Clear cargo space and readd the items as long it's not the type in question
            _containerPos = getPosATL _container;
            _containerDir = getDir _container;

            clearMagazineCargoGlobal _container;

            _container = createVehicle ["groundWeaponHolder", [0, 0, 0], [], 0, "NONE"];

            _unloadTo setVariable [QGVAR(container), container, true];
            _container setDir _containerDir;
            _container setPosATL _containerPos;

            {
                _x params ["_magazineClass", "_magazineAmmo"];

                if (_count != 0 && {_magazineClass == _carryMag} && {_bestAmmoToSend < 0 || {_magazineAmmo == _bestAmmoToSend}}) then {
                    // Process removal
                    _count = _count - 1;
                } else {
                    // Readd
                    _container addMagazineAmmoCargo [_magazineClass, 1, _magazineAmmo];
                };
            } forEach _magazinesAmmo;
        } else {
            [_container, _carryMag, 1, _bestAmmoToSend] call CBA_fnc_removeMagazineCargo;
        };
    };

    if (_bestAmmoToSend == 0) exitWith {};

    TRACE_5("calling addTurretMag event",_vehicle,_turret,_unit,_carryMag,_bestAmmoToSend);
    [QGVAR(addTurretMag), [_vehicle, _turret, _unit, _carryMag, _bestAmmoToSend]] call CBA_fnc_globalEvent;
};


[
TIME_PROGRESSBAR(_timeToLoad),
[_vehicle, _turret, _carryMag, _unit, _container],
_onFinish,
{TRACE_1("load progressBar fail",_this);},
_displayName,
{((_this select 0) call FUNC(reload_canLoadMagazine)) select 0},
["isNotInside"]
] call EFUNC(common,progressBar);
