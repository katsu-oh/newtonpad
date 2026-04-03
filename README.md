# NewtonPad

NewtonPad adds inertia to your touchpad pointer, allowing smooth long‑distance cursor movement.
It also lets you assign shortcut keys to touchpad + keyboard combinations.

### *Inertial Pointer*
When you move the pointer and lift your finger off the touchpad, the pointer continues moving by inertia.
It gradually slows down and eventually stops. When it hits the edge of the screen, it bounces back.
This allows smooth long‑distance movement without increasing the pointer speed.

To move the pointer over a long distance, follow these steps:
1. Flick the pointer roughly in the desired direction to start the inertial movement.
2. Adjust the direction or re‑accelerate as needed.
3. Once the pointer gets close to the target, switch to normal touchpad operation.

Short‑distance movement works the same as before.
If you point precisely, inertia will not act.

### *Shortcut Key Assignment*
While your finger is touching the touchpad, the following key operations are enabled (default settings):
- Left click ........... "J"
- Middle click ......... "K"
- Right click .......... "L"
- Scroll ............... "I" + finger movement
- Pointer movement ..... Arrow keys
- Browser Back ......... "B"
- Browser Forward ...... "N"
- Close Window ......... "X"
- Close Tab ............ "C"
- Search dialog ........ "F"
- Switch Tab ........... "." (period)
- Switch Window ........ Space

## Usage
Run NewtonPad.exe by double‑clicking it, or via Task Scheduler or other methods. Alternatively, you can run NewtonPad_Precision.ahk using AutoHotkey v1.0 (64‑bit).

Before using this tool, set the Windows touchpad sensitivity to "Most sensitive."

To exit the program, touch the touchpad and press "Q" (default). This will terminate the resident process.

You can edit NewtonPad.ini and ThumbKey.ini to change the settings. See the comments inside each file for details.

You can also specify configuration files via command‑line options:
- 1st parameter: Path to NewtonPad.ini (*1, *2)
- 2nd parameter: Path to ThumbKey.ini (*1, *3)

Example: ``NewtonPad.exe NewtonPad2.ini ThumbKey2.ini``

> *1 You may specify either an absolute or relative path. If a relative path is used, the file will be searched in the following locations in order:
> 
> 1. Application data folder (create manually if needed):  
> ```C:\Users\<UserName>\AppData\Roaming\Katsuo\NewtonPad```
> 2. The program's current directory 
> 3. The folder containing the program
> 
> *2 Optional. However, if the 2nd parameter is specified, the 1st cannot be omitted.
>
> *3 Optional.

If you launch the program twice, the previously running instance will automatically exit.
This allows you to switch configuration files by using command‑line options.

## Requirements
- Windows 11 with a Precision Touchpad (Windows 10 64‑bit is also available)

## <br>
©2026 katsu-oh, MIT License: https://github.com/katsu-oh/newtonpad/blob/main/LICENSE.
