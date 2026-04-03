#Requires AutoHotkey v1 64-bit

;-----------------------------------------------------------------------------
;@Ahk2Exe-SetFileVersion 5.0.1.0
;@Ahk2Exe-SetDescription Touchpad Utility "NewtonPad"
;@Ahk2Exe-SetProductName NewtonPad
;@Ahk2Exe-SetProductVersion 5.0.1.0
;@Ahk2Exe-SetCopyright Katsuo`, 2009-2026
;@Ahk2Exe-SetOrigFilename NewtonPad.exe
;-----------------------------------------------------------------------------

#Include %A_ScriptDir%\NewtonPad_Common.ahk

goto,Thumb_End

Thumb_Init_Driver(){
    Global Thumb_Precision_hDevice_Preparsed := 0

    DllCall("LoadLibrary", "Str","hid")

    VarSetCapacity(Device, 8 + A_PtrSize, 0)
    NumPut(0x0D,         Device, 0, "UShort")
    NumPut(0x05,         Device, 2, "UShort")
    NumPut(0x00000100,   Device, 4, "UInt"  )
    NumPut(A_ScriptHwnd, Device, 8, "Ptr"   )
    DllCall("RegisterRawInputDevices", "Ptr",&Device, "UInt",1, "UInt",8 + A_PtrSize)

    OnMessage(0x00FF, "Thumb_Precision_StateOn")
}

Thumb_Precision_StateOn(wParam, lParam) {
    Global Thumb_Precision_hDevice_Preparsed
    Global Thumb_Precision_Preparsed

    RawInputSize := 0
    DllCall("GetRawInputData", "Ptr",lParam, "UInt",0x10000003, "Ptr",0,         "UInt*",RawInputSize, "UInt",8 + A_PtrSize * 2)
    VarSetCapacity(RawInput, RawInputSize, 0)
    DllCall("GetRawInputData", "Ptr",lParam, "UInt",0x10000003, "Ptr",&RawInput, "UInt*",RawInputSize, "UInt",8 + A_PtrSize * 2)
    hDevice := NumGet(RawInput, 8, "Ptr")

    If (hDevice != Thumb_Precision_hDevice_Preparsed) {
        PreparsedSize := 0
        DllCall("GetRawInputDeviceInfo", "Ptr",hDevice, "UInt",0x20000005, "Ptr",0,                          "UInt*",PreparsedSize)
        VarSetCapacity(Thumb_Precision_Preparsed, PreparsedSize, 0)
        Res
     := DllCall("GetRawInputDeviceInfo", "Ptr",hDevice, "UInt",0x20000005, "Ptr",&Thumb_Precision_Preparsed, "UInt*",PreparsedSize) > 0
        If (Res) {
            Thumb_Precision_hDevice_Preparsed := hDevice
        } Else {
            Thumb_Precision_hDevice_Preparsed := 0
        }
    }

    ContactCount := 0
    DllCall("hid\HidP_GetUsageValue", "Int",0x00, "UShort",0x0D, "UShort",0, "UShort",0x54, "UInt*",ContactCount, "Ptr",&Thumb_Precision_Preparsed
                                    , "Ptr",&RawInput + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))

    VarSetCapacity(Caps, 64, 0)
    DllCall("hid\HidP_GetCaps", "Ptr",&Thumb_Precision_Preparsed, "Ptr",&Caps)

    ButtonCapsLength := NumGet(Caps, 46, "UShort")
    VarSetCapacity(ButtonList, ButtonCapsLength * 4, 0)
    DllCall("hid\HidP_GetUsagesEx", "Int",0x00, "UShort",0, "Ptr", &ButtonList, "UInt*",ButtonCapsLength, "Ptr",&Thumb_Precision_Preparsed
                                  , "Ptr",&RawInput + 16 + A_PtrSize * 2, "UInt",RawInputSize - (16 + A_PtrSize * 2))

    Offset := 0
    Touched := 0
    Loop %ButtonCapsLength% {
        UsageId   := NumGet(ButtonList, Offset + 0, "UShort")
        UsagePage := NumGet(ButtonList, Offset + 2, "UShort")
        If (UsagePage = 0x0D) & (UsageId = 0x42) {
            Touched := 1
        }
        Offset += 4
    }

    Thumb_SetState(Touched & (ContactCount = 1))
}

Thumb_End: