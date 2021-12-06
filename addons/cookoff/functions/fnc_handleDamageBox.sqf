#include "script_component.hpp"
/*
 * Author: KoffeinFlummi, commy2
 * Handles all incoming damage for boxi
 *
 * Arguments:
 * HandleDamage EH <ARRAY>
 *
 * Return Value:
 * Damage to be inflicted. <NUMBER>
 *
 * Example:
 * _this call ace_cookoff_fnc_handleDamageBox
 *
 * Public: No
 */

params ["_vehicle", "", "_damage", "_source", "_ammo", "_hitIndex", "_shooter"];

// it's already dead, who cares?
if (damage _vehicle >= 1) exitWith {};

// If cookoff is disabled exit
if (_vehicle getVariable [QGVAR(enable), GVAR(enable)] in [0, false]) exitWith {};

// get hitpoint name
private _hitpoint = "#structural";

if (_hitIndex != -1) then {
    _hitpoint = toLower ((getAllHitPointsDamage _vehicle param [0, []]) select _hitIndex);
};

// get change in damage
private _oldDamage = 0;

if (_hitpoint isEqualTo "#structural") then {
    _oldDamage = damage _vehicle;
} else {
    _oldDamage = _vehicle getHitIndex _hitIndex;
};

if (_hitpoint == "#structural" && _damage > 0.5) then {
    // Almost always catch fire when hit by an explosive
    if (IS_EXPLOSIVE_AMMO(_ammo)) then {
        _vehicle call FUNC(cookOffBox);
    } else {
        // Need magazine to check for tracers
        private _mag = "";
        if (_source == _shooter) then {
            _mag = currentMagazine _source;
        } else {
            _mag = _source currentMagazineTurret ([_shooter] call CBA_fnc_turretPath);
        };
        private _magCfg = configFile >> "CfgMagazines" >> _mag;

        // Magazine could have changed during flight time (just ignore if so)
        if (getText (_magCfg >> "ammo") == _ammo) then {
            // If magazine's tracer density is high enough then low chance for cook off
            private _tracers = getNumber (_magCfg >> "tracersEvery");
            if (_tracers >= 1 && {_tracers <= 4}) then {
                if (random 1 < _oldDamage*0.05) then {
                    _vehicle call FUNC(cookOffBox);
                };
            };
        };
    };

    // prevent destruction, let cook-off handle it if necessary
    _damage min 0.89
} else {
    _damage
};
