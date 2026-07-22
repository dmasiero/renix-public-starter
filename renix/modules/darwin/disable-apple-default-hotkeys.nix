# This Nix expression defines Apple Symbolic HotKeys to disable.
{ lib }:

let
  hotkeyEnums = {
    moveFocusToMenuBar = 7;
    moveFocusToDock = 8;
    moveFocusToActiveOrNextWindow = 9;
    moveFocusToWindowToolbar = 10;
    moveFocusToFloatingWindow = 11;
    turnKeyboardAccessOnOrOff = 12;
    changeWayTabMovesFocus = 13;
    moveFocusToNextWindow = 27;
    missionControl = 32;
    missionControlDedicatedKey = 34;
    applicationWindows = 35;
    showDesktop = 36;
    showDesktopDedicatedKey = 37;
    moveFocusToWindowDrawer = 51;
    turnDockHidingOnOff = 52;
    moveFocusToStatusMenus = 57;
    selectPreviousInputSource = 60;
    showSpotlightSearch = 64;
    moveLeftASpace = 79;
    moveLeftASpaceDedicatedKey = 80;
    moveRightASpace = 81;
    moveRightASpaceDedicatedKey = 82;
    switchToDesktop1 = 118;
    switchToDesktop2 = 119;
    switchToDesktop3 = 120;
    showLaunchpad = 160;
    showNotificationCenter = 163;
    turnDoNotDisturbOnOff = 175;
  };

  hotkeysToDisable = with hotkeyEnums; [
    moveFocusToMenuBar
    moveFocusToDock
    moveFocusToActiveOrNextWindow
    moveFocusToWindowToolbar
    moveFocusToFloatingWindow
    turnKeyboardAccessOnOrOff
    changeWayTabMovesFocus
    moveFocusToNextWindow
    missionControl
    missionControlDedicatedKey
    applicationWindows
    showDesktop
    showDesktopDedicatedKey
    moveFocusToWindowDrawer
    turnDockHidingOnOff
    moveFocusToStatusMenus
    selectPreviousInputSource
    showSpotlightSearch
    moveLeftASpace
    moveLeftASpaceDedicatedKey
    moveRightASpace
    moveRightASpaceDedicatedKey
    switchToDesktop1
    switchToDesktop2
    switchToDesktop3
    showLaunchpad
    showNotificationCenter
    turnDoNotDisturbOnOff
  ];

  appleSymbolicHotkeysSettings = lib.listToAttrs (
    map (id: {
      name = builtins.toString id;
      value = { enabled = false; };
    }) (lib.sort lib.lessThan hotkeysToDisable)
  );
in
{
  "com.apple.symbolichotkeys".AppleSymbolicHotKeys = appleSymbolicHotkeysSettings;
}
