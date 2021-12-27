#include "script_component.hpp"
/*
 * Author: commy2, SilentSpike
 * HandleDamage EH where wound events are raised based on incoming damage.
 * Be aware that for each source of damage, the EH can fire multiple times (once for each hitpoint).
 * We store these incoming damages and compare them on our final hitpoint: "ace_hdbracket".
 *
 * Arguments:
 * Handle damage EH
 *
 * Return Value:
 * Damage to be inflicted <NUMBER>
 *
 * Public: No
 */
// for travis
#define HIT_STRUCTURAL QGVAR($#structural)

params ["_unit", "_selection", "_damage", "_shooter", "_ammo", "_hitPointIndex", "_instigator", "_hitpoint"];

// HD sometimes triggers for remote units - ignore.
if !(local _unit) exitWith {nil};

// Get missing meta info
private _oldDamage = 0;

if (_hitPoint isEqualTo "") then {
    _hitPoint = "#structural";
    _oldDamage = damage _unit;
} else {
    _oldDamage = _unit getHitIndex _hitPointIndex;
};

// Damage can be disabled with old variable or via sqf command allowDamage
if !(isDamageAllowed _unit && {_unit getVariable [QEGVAR(medical,allowDamage), true]}) exitWith {_oldDamage};

private _newDamage = _damage - _oldDamage;
// Get armor value of hitpoint and calculate damage before armor
private _armor = [_unit, _hitpoint] call FUNC(getHitpointArmor);
private _realDamage = _newDamage * _armor;
TRACE_4("Received hit",_hitpoint,_ammo,_newDamage,_realDamage);

// Drowning doesn't fire the EH for each hitpoint so the "ace_hdbracket" code never runs
// Damage occurs in consistent increments
if (
    _hitPoint isEqualTo "#structural" &&
    {getOxygenRemaining _unit <= 0.5} &&
    {_damage isEqualTo (_oldDamage + 0.005)}
) exitWith {
    TRACE_5("Drowning",_unit,_shooter,_instigator,_damage,_newDamage);
    [QEGVAR(medical,woundReceived), [_unit, [[_newDamage, "Body", _newDamage]], _unit, "drowning"]] call CBA_fnc_localEvent;

    0
};

// Crashing a vehicle doesn't fire the EH for each hitpoint so the "ace_hdbracket" code never runs
// It does fire the EH multiple times, but this seems to scale with the intensity of the crash
private _vehicle = vehicle _unit;
if (
    EGVAR(medical,enableVehicleCrashes) &&
    {_hitPoint isEqualTo "#structural"} &&
    {_ammo isEqualTo ""} &&
    {_vehicle != _unit} &&
    {vectorMagnitude (velocity _vehicle) > 5}
    // todo: no way to detect if stationary and another vehicle hits you
) exitWith {
    TRACE_5("Crash",_unit,_shooter,_instigator,_damage,_newDamage);
    [QEGVAR(medical,woundReceived), [_unit, [[_newDamage, _hitPoint, _newDamage]], _unit, "vehiclecrash"]] call CBA_fnc_localEvent;

    0
};

// Being inside an exploding vehicle doesn't fire the EH for each hitpoint so the "ace_hdbracket" code never runs
// _ammo is always "FuelExplosion", EH fires for each explosion. Damage is dependent on amount of fuel remaining in the vehicle
if (
    _hitPoint isEqualTo "#structural" &&
    {_vehicle != _unit} &&
    {_ammo isEqualTo "FuelExplosion"}
) exitWith {
    private _destrType = getText (configOf _vehicle >> "destrType");
    // Skip vehicles that don't explode
    if (_destrType == "") exitWith {};
    // DestructWreck is typically found on Aircraft/Heavy vehicles, DestructDefault is typically found on cars & boats.
    private _lethality = [1.25, 2] select (_destrType == "DestructWreck");
    // Focus damage on chest & head for increased lethality
    [QEGVAR(medical,woundReceived), [_unit, [[_newDamage * _lethality, "Body", _newDamage * _lethality]], _shooter, _ammo]] call CBA_fnc_localEvent;
    // Set crew on fire
    if (["ace_fire"] call EFUNC(common,isModLoaded)) then {
        [QEGVAR(fire,burn), [_unit, 5 * _newDamage, _shooter]] call CBA_fnc_globalEvent;
    };
    TRACE_5("Vehicle Destroyed",_unit,_shooter,_instigator,_damage,_newDamage);

    0
};

// This hitpoint is set to trigger last, evaluate all the stored damage values
// to determine where wounds are applied
if (_hitPoint isEqualTo "ace_hdbracket") exitWith {
    _unit setVariable [QEGVAR(medical,lastDamageSource), _shooter];
    _unit setVariable [QEGVAR(medical,lastInstigator), _instigator];

    private _damageStructural = _unit getVariable [HIT_STRUCTURAL, 0];

    // --- Head
    private _damageHead = [
        _unit getVariable [QGVAR($HitFace), [0,0]],
        _unit getVariable [QGVAR($HitNeck), [0,0]],
        _unit getVariable [QGVAR($HitHead), [0,0]]
    ];
    _damageHead sort false;
    _damageHead = _damageHead select 0;

    // --- Body
    private _damageBody = [
        _unit getVariable [QGVAR($HitPelvis), [0,0]],
        _unit getVariable [QGVAR($HitAbdomen), [0,0]],
        _unit getVariable [QGVAR($HitDiaphragm), [0,0]],
        _unit getVariable [QGVAR($HitChest), [0,0]]
        // HitBody removed as it's a placeholder hitpoint and the high armor value (1000) throws the calculations off
    ];
    _damageBody sort false;
    _damageBody = _damageBody select 0;

    // --- Arms and Legs
    private _damageLeftArm = _unit getVariable [QGVAR($HitLeftArm), [0,0]];
    private _damageRightArm = _unit getVariable [QGVAR($HitRightArm), [0,0]];
    private _damageLeftLeg = _unit getVariable [QGVAR($HitLeftLeg), [0,0]];
    private _damageRightLeg = _unit getVariable [QGVAR($HitRightLeg), [0,0]];

    // Find hit point that received the maxium damage
    // Priority used for sorting if incoming damage is equivalent (e.g. max which is 4)
    private _allDamages = [
        _damageHead       + [PRIORITY_HEAD,       "Head"],
        _damageBody       + [PRIORITY_BODY,       "Body"],
        _damageLeftArm    + [PRIORITY_LEFT_ARM,   "LeftArm"],
        _damageRightArm   + [PRIORITY_RIGHT_ARM,  "RightArm"],
        _damageLeftLeg    + [PRIORITY_LEFT_LEG,   "LeftLeg"],
        _damageRightLeg   + [PRIORITY_RIGHT_LEG,  "RightLeg"],
        _damageStructural + [PRIORITY_STRUCTURAL, "#structural"]
    ];
    TRACE_2("incoming",_allDamages,_damageStructural);

    _allDamages sort false;
    _allDamages = _allDamages apply {[_x select 1, _x select 3, _x select 0]};
    
    // Environmental damage sources all have empty ammo string
    // No explicit source given, we infer from differences between them
    if (_ammo isEqualTo "") then {
        // Any collision with terrain/vehicle/object has a shooter
        // Check this first because burning can happen at any velocity
        if !(isNull _shooter) then {
            /*
              If shooter != unit then they hit unit, otherwise it could be:
               - Unit hitting anything at speed
               - An empty vehicle hitting unit
               - A physX object hitting unit
               Assume fall damage for downward velocity because it's most common
            */
            if (_shooter == _unit && {(velocity _unit select 2) < -2}) then {
                _ammo = "falling";
                TRACE_5("Fall",_unit,_shooter,_instigator,_damage,_allDamages);
            } else {
                _ammo = "collision";
                TRACE_5("Collision",_unit,_shooter,_instigator,_damage,_allDamages);
            };
        } else {
            // Anything else is almost guaranteed to be fire damage
            _ammo = "fire";
            TRACE_5("Fire Damage",_unit,_shooter,_instigator,_damage,_allDamages);
        };
    };

    // No wounds for minor damage
    // TODO check if this needs to be changed for burning damage (occurs as lots of small events that we add together)
    if ((_allDamages select 0 select 0) > 1E-3) then {
        TRACE_1("received",_allDamages);
        [QEGVAR(medical,woundReceived), [_unit, _allDamages, _shooter, _ammo]] call CBA_fnc_localEvent;
    };

    // Clear stored damages otherwise they will influence future damage events
    // (aka wounds will pile onto the historically most damaged hitpoint)
    {
        _unit setVariable [_x, nil];
    } forEach [
        QGVAR($HitFace),QGVAR($HitNeck),QGVAR($HitHead),
        QGVAR($HitPelvis),QGVAR($HitAbdomen),QGVAR($HitDiaphragm),QGVAR($HitChest),QGVAR($HitBody),
        QGVAR($HitLeftArm),QGVAR($HitRightArm),QGVAR($HitLeftLeg),QGVAR($HitRightLeg),
        QGVAR($#structural)
    ];

    0
};

// Damages are stored for "ace_hdbracket" event triggered last
_unit setVariable [format [QGVAR($%1), _hitPoint], [_realDamage, _newDamage]];

// Engine damage to these hitpoints controls blood visuals, limping, weapon sway
// Handled in fnc_damageBodyPart, persist here
if (_hitPoint in ["hithead", "hitbody", "hithands", "hitlegs"]) exitWith {_oldDamage};

// We store our own damage values so engine damage is unnecessary
0
