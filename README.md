# FlareUI: Cast Missing Buffs on Mouse Wheel

An extension for the FlareUI interface that lets you rebuff without thinking about it: when a buff is missing, simply scrolling your mouse wheel casts it.

## What it does

FlareUI's Buff Reminders show an icon on screen when one of your buffs is missing, such as Power Word: Fortitude, Mark of the Wild, Arcane Intellect or Lightning Shield. In the base setup you then have to find the spell on your bars, or click the reminder icon, to cast it.

With this addon, while a reminder is showing, the next scroll of your mouse wheel casts the missing buff for you. The camera still zooms as usual, so the wheel keeps doing its normal job at the same time.

Since most players scroll the wheel constantly while moving around, missing buffs get recast almost without noticing.

## Examples

- **Priest:** your Power Word: Fortitude runs out while you are walking to the next quest. The reminder appears, you nudge the camera with the wheel as you always do, and Fortitude is back.
- **Shaman:** Lightning Shield drops after a fight. Your next scroll puts it back up before the next pull.
- **Druid, Mage, Paladin and others:** any buff you have set up in FlareUI's Buff Reminders works the same way.

## How it changes your play

- You stop running around without your buffs because you did not notice the reminder.
- You no longer need a button on your bars, or a click on the reminder icon, for buffs you only cast every half hour.
- Rebuffing between fights happens as part of normal movement instead of being a separate chore.

## Built to be safe

- **Out of combat only.** In a fight your mouse wheel is left completely alone.
- **Never while mounted.** A scroll will not dismount you.
- **Never while eating or drinking.** A scroll will not stand you up and waste your food or water.
- **Never while you are busy.** It waits while you are bandaging, fishing, using your hearthstone, gathering, crafting or casting anything else, and while you are stealthed or feigning death.
- **Never in another form.** It will not take you out of Ghost Wolf or a druid form; the buff waits until you are back in your normal form.
- **Only buffs you by default.** "Only Buffs on Myself" is switched on from the start, so a scroll never casts on another player unless you choose that.
- **Spells only.** It never uses an item and never runs a macro.
- **Only wheel keys bound to camera zoom are used.** If you have bound the wheel to something else, that binding is not touched.
- **Nothing missing, nothing changed.** When no reminder is showing, your wheel behaves exactly as it does without the addon.
- **Your key bindings are never edited.** The addon borrows the wheel only while a buff is missing and gives it back immediately.

## Options

The options appear inside FlareUI's own settings window, under Buff Reminders > When and Where, in the Alerts section. You can also type `/flarewheel`, or open the game's Options > AddOns.

- **Cast on Mouse Wheel:** on or off.
- **Only Buffs on Myself (on by default):** the wheel never casts on someone else in your group. Switch it off to let a scroll buff your group too.
- **Only Above Mana:** the wheel only casts while your mana is at or above the amount you choose (10% to 90%), so it never spends mana you are saving. Off by default.

## Good to know

- It follows FlareUI's Buff Reminders, so choose there which buffs you want to be reminded about. Buffs you have not enabled there are never cast.

## Install

1. Download the latest zip from this project's [Releases](https://github.com/ronborens/FlareUI_WheelBuffs/releases).
2. Extract it into your game's `Interface/AddOns` folder, so that `FlareUI_WheelBuffs` sits beside `FlareUI`.
3. Restart the game.

To run it straight from the source, clone this repository into `Interface/AddOns` as `FlareUI_WheelBuffs`.

## Problems and ideas

Please open an [issue](https://github.com/ronborens/FlareUI_WheelBuffs/issues) and say which FlareUI version you have.

## Requirements

- [FlareUI](https://www.curseforge.com/wow/addons/flareui) must be installed and enabled, with its Buff Reminders switched on.

This is an unofficial extension. It is not made or endorsed by the FlareUI authors, so please report problems here and not to them. MIT licensed.
