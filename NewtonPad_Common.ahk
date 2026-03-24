ListLines, Off
#NoEnv
#NoTrayIcon
#Persistent
#MaxHotkeysPerInterval 200
#SingleInstance Force
#KeyHistory 0

;Initialize
SetBatchLines, -1
SetKeyDelay, -1
SetMouseDelay, -1
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen
Critical, 5
fileNewton := ResolvePath(GetArg(1, "NewtonPad.ini"))
fileThumbKey := ResolvePath(GetArg(2, "ThumbKey.ini"))
TimerErr := 1
Thumb_Init_Driver()
Newton_Init()
Thumb_KeyInit()
Liftless_Init()
OnExit, ExitProc

goto, Newton_End


GetArg(Index, Default){
	Global
	Local Value
	Value := %Index%
	If(Value = ""){
		Value := Default
	}
	Return Value
}


AddBS(Path){
	Global
	Local CS
	StringRight, CS, Path, 2
	If(CS = ":\"){
		Return Path
	}Else{
		Return Path . "\"
	}
}


ResolvePath(Path){
	Global
	Local C, SS, AppData
	StringMid, C, Path, 2, 1
	StringLeft, SS, Path, 2
	If(C = ":") Or (SS = "\\"){
		Return Path
	}
	EnvGet, AppData, APPDATA
	IfExist, % AddBS(AppData) . "Katsuo\NewtonPad\" . Path
		Return AddBS(AppData) . "Katsuo\NewtonPad\" . Path
	IfExist, % AddBS(A_WorkingDir) . Path
		Return AddBS(A_WorkingDir) . Path
	Return AddBS(A_ScriptDir) . Path
}

ExitProc:
	If(WheelScrollLines != ""){
		DllCall("SystemParametersInfo", UInt, 105, UInt, WheelScrollLines, UInt, 0, UInt, 0) ; SPI_SETWHEELSCROLLLINES
	}
	If(iniBlinkTime > 0){
		SystemCursor(1)
	}
	Thumb_TransparentOver("Off")
	ExitApp


CriticalOff(SleepTime = -1){
	Critical, Off
	Sleep, SleepTime
	Critical, 5
}


TickCountDiff(After, Before){
	If(Before - After >= 2 ** 31){
		return After - Before + 2 ** 32
	}Else{
		return After - Before
	}
}


MinusHalfTimerErr(MilliSecond){
	Global
	Local T
	T := MilliSecond - TimerErr * 5
	If(T <= 5){
		Return 5
	}Else{
		Return T
	}
}


SystemCursor(On){   ; On : SystemCursorOn = 1; OFF : others
	Global
	Local IntPtr := A_PtrSize ? "Ptr" : "UInt"
	Local system_cursors := "32512|32513|32649"
	Static AndMask, XorMask, $, h_cursor
		,c0,  c1,  c2,  c3
		,   Off1,Off2,Off3
		,   Onn1,Onn2,Onn3
	If($ = ""){
		VarSetCapacity(AndMask, 32*4, 0xFF)
		VarSetCapacity(XorMask, 32*4, 0x00)
		StringSplit c, system_cursors, |
		Loop %c0%{
			Off%A_Index% := DllCall("CreateCursor", IntPtr, 0, "int", 0, "int", 0
				, "int", 32, "int", 32, IntPtr, &AndMask, IntPtr, &XorMask, IntPtr)
		}
	}
	If($ = "On") & (On = 0) | ($ = ""){
		$ := "On"
		Loop %c0%{
			If(Onn%A_Index% != ""){
				DllCall("DestroyCursor", IntPtr, Onn%A_Index%)
			}
			h_cursor := DllCall("LoadCursor", IntPtr, 0, IntPtr, c%A_Index%, IntPtr)
			Onn%A_Index% := DllCall("CopyImage", IntPtr, h_cursor, "uint", 2, "int", 0, "int", 0, "uint", 0, IntPtr)
		}
	}
	If(On = 0){
		$ := "Off"
	}Else{
		$ := "Onn"
	}
	Loop %c0%{
		h_cursor := DllCall("CopyImage", IntPtr, %$%%A_Index%, "uint", 2, "int", 0, "int", 0, "uint", 0, IntPtr)
		DllCall("SetSystemCursor", IntPtr, h_cursor, "uint", c%A_Index%)
	}
	If($ = "Onn"){
		$ := "On"
	}
}


Liftless_Init(){
	Global
	iniLiftTouchTime := IniReadFloat(fileNewton, "LiftlessTap", "LiftTouchTime", 35, 0, 999)
	iniTouchPressTime := IniReadFloat(fileNewton, "LiftlessTap", "TouchPressTime", 2, 1, 999)
	iniPressClickTime := IniReadFloat(fileNewton, "LiftlessTap", "PressClickTime", 18, 1, 999)
	iniDragLockTime := IniReadFloat(fileNewton, "LiftlessTap", "DragLockTime", 40, 1, 999)
	iniNearBy := IniReadInteger(fileNewton, "LiftlessTap", "NearBy", 2, 0, 999)
	iniBeginnersTip := IniReadString(fileNewton, "LiftlessTap", "BeginnersTip", "")
	iniDragTip := IniReadString(fileNewton, "LiftlessTap", "DragTip", "*")
	iniBeginnersTipTrans := 255 - Round(IniReadFloat(fileNewton, "LiftlessTap", "BeginnersTipTrans", 0, 0, 100) * 2.55)
	iniDragTipTrans := 255 - Round(IniReadFloat(fileNewton, "LiftlessTap", "DragTipTrans", 20, 0, 100) * 2.55)
	iniBlinkTime := IniReadFloat(fileNewton, "LiftlessTap", "BlinkTime", 0, 0, 999)
}


Liftless_Up(){
	Global
	MouseGetPos, UpX, UpY
	UpTick := A_TickCount
	If(LiftlessDrag = 1){
		SetTimer, Liftless_Release, Off
		SetTimer, Liftless_Release, % MinusHalfTimerErr(iniDragLockTime * 10)
		Return
	}
	If(LiftlessPress = 1){
		SetTimer, Liftless_Release, Off
		Liftless_Release_Func()
		LiftlessPress := ""
		LiftlessActive := 1
		Return
	}
	If(LiftlessActive = ""){
		LiftlessActive := 1
		Return
	}
}


Liftless_Down(){
	Global
	MouseGetPos, DownX, DownY
	DownTick := A_TickCount
	If(LiftlessActive = 1){
		If(TickCountDiff(DownTick, UpTick) <= iniLiftTouchTime * 10) & (Abs(UpX - DownX) <= iniNearBy) & (Abs(UpY - DownY) <= iniNearBy){
			If(iniBlinkTime > 0){
				if((iniTouchPressTime - iniBlinkTime) < 1){
					GoSub, Liftless_HideCursor
				}Else{
					SetTimer, Liftless_HideCursor, % -MinusHalfTimerErr((iniTouchPressTime - iniBlinkTime) * 10)
				}
			}
			SetTimer, Liftless_Press, % -MinusHalfTimerErr(iniTouchPressTime * 10)
			Local TipTime
			TipTime := Round(iniTouchPressTime * 0.9) - 2
			If(TipTime < 1){
				TipTime := 1
			}
			If(iniTouchPressTime <= 1){
				ToolTip, % iniBeginnersTip
				SetTimer, Liftless_TrailPressTipBiginners, 10
			}
			SetTimer, Liftless_PressTip, % -TipTime * 10
		}Else{
			LiftlessActive := ""
		}
		Return
	}
	If(LiftlessDrag = 1){
		SetTimer, Liftless_Release, Off
		Return
	}
}


Liftless_ShowCursor:
	SetTimer, Liftless_HideCursor, Off
	SystemCursor(1)
	Return

Liftless_HideCursor:
	SystemCursor(0)
	SetTimer, Liftless_ShowCursor, % -MinusHalfTimerErr(iniBlinkTime * 10)
	Return


Liftless_PressTip:
	Liftless_PressTip_Func()
	Return

Liftless_PressTip_Func(){
	Global
	MouseGetPos, PressX, PressY
	DragTick := A_TickCount
	If(LiftlessActive = 1){
		If(Abs(PressX - DownX) <= iniNearBy) & (Abs(PressY - DownY) <= iniNearBy){
			If(iniTouchPressTime > 2){
				Liftless_ShowPressTip_Func(iniBeginnersTip)
				SetTimer, Liftless_TrailPressTipBiginners, 10
			}
		}
	}
}

Liftless_ShowPressTip_Func(Text){
	Local TipX, TipY
	MouseGetPos, TipX, TipY
	TipX += 12
	TipY += 12
	ToolTip, %Text%, %TipX%, %TipY%
}


Liftless_TrailPressTipBiginners:
	Liftless_TrailPressTip_Func(iniBeginnersTip, iniBeginnersTipTrans)
	Return
Liftless_TrailPressTipDrag:
	Liftless_TrailPressTip_Func(iniDragTip, iniDragTipTrans)
	Return


Liftless_TrailPressTip_Func(Text, Trans){
	Global
	Local PID
	Process, Exist
	PID := ErrorLevel
	WinSet, Transparent, %Trans%, ahk_pid %PID% ahk_class tooltips_class32
	Local TipX, TipY
	MouseGetPos, TipX, TipY
	Local X, Y, W, H
	WinGetPos, X, Y, W, H, ahk_pid %PID% ahk_class tooltips_class32
	TipX += 12
	TipY += 12
	If(TipX + W > A_ScreenWidth - 1){
		TipX := A_ScreenWidth - 1 - W
	}
	If(TipY + H > A_ScreenHeight - 1){
		TipY := A_ScreenHeight - 1 - H
	}
	If(X = "") | (Abs(TipX - X) >= 1) | (Abs(TipY - Y) >= 1){
		If(LiftlessDrag = 1) | (LiftlessPress = 1){
			ToolTip, %Text%, %TipX%, %TipY%
		}
	}
	WinSet, Transparent, %Trans%, ahk_pid %PID% ahk_class tooltips_class32
}


Liftless_HidePressTip(){
	Global
	Local PID, Trans
	Process, Exist
	PID := ErrorLevel
	WinGet, Trans, Transparent, ahk_pid %PID% ahk_class tooltips_class32
	SetTimer, Liftless_TrailPressTipBiginners, Off
	SetTimer, Liftless_TrailPressTipDrag, Off
	WinSet, Transparent, % Trans / 2, ahk_pid %PID% ahk_class tooltips_class32
	CriticalOff(30)
	WinSet, Transparent, % Trans / 4, ahk_pid %PID% ahk_class tooltips_class32
	CriticalOff(30)
	WinSet, Transparent, % Trans / 8, ahk_pid %PID% ahk_class tooltips_class32
	CriticalOff(30)
	ToolTip
	Return
}


Liftless_Press:
	Liftless_Press_Func()
	Return

Liftless_Press_Func(){
	Global
	MouseGetPos, PressX, PressY
	DragTick := A_TickCount
	If(iniBlinkTime > 0){
		GoSub, Liftless_ShowCursor
	}
	If(LiftlessActive = 1){
		If(Abs(PressX - DownX) <= iniNearBy) & (Abs(PressY - DownY) <= iniNearBy){
			SendInput, {Blind}{LButton Down}
			LiftlessPress := 1
			SetTimer, Liftless_Release, % -MinusHalfTimerErr(iniPressClickTime * 10)
		}Else{
			Liftless_HidePressTip()
		}
		LiftlessActive := ""
	}
}


Liftless_Release:
	Liftless_Release_Func()
	Return

Liftless_Release_Func(){
	Global
	PreReleaseX := ReleaseX
	PreReleaseY := ReleaseY
	MouseGetPos, ReleaseX, ReleaseY
	If(LiftlessPress = 1){
		If(Abs(ReleaseX - PressX) <= iniNearBy) & (Abs(ReleaseY - PressY) <= iniNearBy){
			SendInput, {Blind}{LButton Up}
			Liftless_HidePressTip()
			LiftlessActive := 1
		}Else{
			LiftlessDrag := 1
			SetTimer, Liftless_TrailPressTipBiginners, Off
			Liftless_ShowPressTip_Func(iniDragTip)
			SetTimer, Liftless_TrailPressTipDrag, 10
			If(Thumb_State = 0){
				SetTimer, Liftless_Release, % MinusHalfTimerErr(iniDragLockTime * 10)
			}
		}
		LiftlessPress := ""
		Return
	}
	If(LiftlessDrag = 1){
		If(Abs(ReleaseX - UpX) <= iniNearBy) & (Abs(ReleaseY - UpY) <= iniNearBy)
		| (Thumb_State != 1) & (Abs(PreReleaseX - ReleaseX) <= 0) & (Abs(PreReleaseY - ReleaseY) <= 0){
			SetTimer, Liftless_Release, Off
			SendInput, {Blind}{LButton Up}
			Liftless_HidePressTip()
			LiftlessDrag := ""
			LiftlessActive := 1
		}
		Return
	}
}


ToInteger(Value, Default, Min, Max){
	Local Res
	Res := Value
	If Res Is Float
		Res := Round(Res)
	If Res Is Not Integer
		Res := Default
	If(Res < Min)
		Res := Min
	If(Res > Max)
		Res := Max
	Return Res * 1
}


ToFloat(Value, Default, Min, Max){
	Local Res
	Res := Value
	If Res Is Not Number
		Res := Default
	If(Res < Min)
		Res := Min
	If(Res > Max)
		Res := Max
	Return Res * 1
}


Thumb_KeyInit(){
	Global
	Local SpecialChars := "+^!#<>*~$& "
	Local AlwaysUpKeys := "vkf0sc03A vkF2sc070"
	Local temp, KK, AA, PP, QQ, Pos

	iniUnhookDelay := IniReadFloat(fileNewton, "ThumbKey", "UnhookDelay", 40, 1, 999)
	iniScrollSmooth := IniReadString(fileNewton, "ThumbKey", "ScrollSmooth", "<sysListView32>:24|<Internet Explorer_Server>:20")
	iniScrollVelocity := IniReadFloat(fileNewton, "ThumbKey", "ScrollVelocity", 0.2, -999, 999) / 100
	iniScrollAcceleration := IniReadFloat(fileNewton, "ThumbKey", "ScrollAcceleration", 0.5, 0, 999) / 100
	iniScrollResistance := IniReadFloat(fileNewton, "ThumbKey", "ScrollResistance", 3.0, 0, 100) / 100
	iniScrollShowWindow := IniReadInteger(fileNewton, "ThumbKey", "ScrollShowWindow", 85, 0, 100) / 100
	iniScrollWheelLines := IniReadInteger(fileNewton, "ThumbKey", "ScrollWheelLines", 0, 0, 100)

	KeyCount := 1

	Loop, Read, %fileThumbKey%
	{
		KK := ""
		AA := ""
		PP := ""
		QQ := ""
		Loop, Parse, A_LoopReadLine, CSV
		{
			If(A_Index = 1){
				KK := A_LoopField
			}Else If(A_Index = 2){
				AA := A_LoopField
			}Else If(A_Index = 3){
				PP := A_LoopField
			}Else If(A_Index = 4){
				QQ := A_LoopField
			}
		}
		StringLeft temp, KK, 3
		StringLower temp, temp
		If(temp = "rem"){
			Continue
		}
		KK := RegExReplace(KK, "^\s*", "")
		KK := RegExReplace(KK, "\s*$", "")
		AA := RegExReplace(AA, "^\s*", "")
		AA := RegExReplace(AA, "\s*$", "")
		StringLower AA, AA
		If(AA != "sendinput") and (AA != "run") and (AA != "exitapp") and (AA != "scroll"){
			Continue
		}
		If(AA = "scroll") & (iniScrollWheelLines >= 1){
			If(WheelScrollLines = ""){
				DllCall("SystemParametersInfo", UInt, 104, UInt, 0, UIntP, WheelScrollLines, UInt, 0) ; SPI_GETWHEELSCROLLLINES
				DllCall("SystemParametersInfo", UInt, 105, UInt, iniScrollWheelLines, UInt, 0, UInt, 0) ; SPI_SETWHEELSCROLLLINES
			}
		}
		KK_%KeyCount% := KK
		AA_%KeyCount% := AA
		PP_%KeyCount% := PP
		QQ_%KeyCount% := QQ
		DD_%KeyCount% := 0
		DT_%KeyCount% := A_TickCount

		KKK_%KeyCount% := KK_%KeyCount%
		Loop, Parse, SpecialChars
		{
			StringGetPos, Pos, KKK_%KeyCount%, %A_LoopField%, R, 1
			If(Pos >= 0){
				StringMid, KKK_%KeyCount%, KKK_%KeyCount%, Pos + 2
			}
		}

		UP_%KeyCount% := 0
		Loop, Parse, AlwaysUpKeys, %A_Space%
		{
			If(KKK_%KeyCount% = A_LoopField){
				UP_%KeyCount% := 1
				Break
			}
		}

		KeyCount++
	}
	KeyCount--

	Loop, %KeyCount%{
		Hotkey, % KK_%A_Index%, Thumb_KeyAction, On UseErrorLevel
		Hotkey, % KK_%A_Index% . " Up", Thumb_KeyUpAction, On UseErrorLevel
	}
	Suspend, On
}


Thumb_KeyAction:
	Thumb_KeyAction_Func(A_ThisHotkey)
	Return


Thumb_KeyAction_Func(Key){
	Global
	Local Index
	Loop, %KeyCount%{
		If(KK_%A_Index% = Key){
			Index := A_Index
			Break
		}
	}
	If(AA_%Index% = "sendinput"){
		If(QQ_%Index% = ""){
			SendInput, % PP_%Index%
		}Else{
			If(DD_%Index% = 0){
				SendInput, % PP_%Index%
			}
		}
	}Else If(AA_%Index% = "run"){
		If(DD_%Index% = 0){
			Run, % PP_%Index%, , % QQ_%Index% . " UseErrorLevel"
		}
	}Else If(AA_%Index% = "exitapp"){
		ExitApp
	}
	If(DD_%Index% = 0){
		DD_%Index% := 1
		SetTimer, Thumb_Unhook, Off
		SetTimer, Thumb_TestKeyUp, Off
		SetTimer, Thumb_TestKeyUp, 10
	}
}


Thumb_KeyUpAction:
	Thumb_KeyUpAction_Func(A_ThisHotkey)
	Return

Thumb_KeyUpAction_Func(Key){
	Local Index
	Loop, %KeyCount%{
		If(KK_%A_Index% . " Up" = Key){
			Index := A_Index
			Break
		}
	}
	If(DD_%Index% = 0){
		If(TickCountDiff(A_TickCount, DT_%Index%) > TimerErr * 15) | (TickCountDiff(A_TickCount, DT_%Index%) < 0){
			Thumb_KeyAction_Func(KK_%Index%)
		}
	}
	Return
}


Thumb_TestKeyUp:
	Thumb_TestKeyUp_Func()
	Return

Thumb_TestKeyUp_Func(){
	Global
	Local KeyPressed := 0
	Loop, %KeyCount%{
		If(DD_%A_Index% = 1){
			If(UP_%A_Index% = 0) & (GetKeyState(KKK_%A_Index%, "P")){
				KeyPressed := 1
				If(AA_%A_Index% = "scroll"){
					Thumb_Scroll()
				}
			}Else{
				If(AA_%A_Index% = "sendinput") & (QQ_%A_Index% != ""){
					SendInput, % QQ_%A_Index%
				}Else If(AA_%A_Index% = "scroll"){
					Thumb_ScrollStartPosY := ""
					ToolTip, , , , 2
					Thumb_TransparentOver("Off")
				}
				DD_%A_Index% := 0
				DT_%A_Index% := A_TickCount
			}
		}
	}
	If(KeyPressed = 0){
		SetTimer, Thumb_TestKeyUp, Off
		If(Thumb_State != 1){
			SetTimer, Thumb_Unhook, Off
			SetTimer, Thumb_Unhook, % -MinusHalfTimerErr(iniUnhookDelay * 10)
		}
	}
}

Thumb_Scroll(){
	Global
	Local PosX, PosY, Wheel, OffsetY, SlowY, ProcessName, Resolution, A_ProcessName
	Static Hwnd, Ctrl, CtrlName, Smooth, lp, CounterY, CounterNotchY, PrevTickCount
	MouseGetPos, PosX, PosY
	If(Thumb_ScrollStartPosY = ""){
		lp := PosY << 16 | PosX
		MouseGetPos, , , Hwnd, Ctrl, 3
		SendMessage, 0x84, 0, %lp%, , ahk_id %Ctrl% ; WM_NCHITTEST
		If(ErrorLevel = 4294967295){
			MouseGetPos, , , , Ctrl, 2
		}
		WinGet, ProcessName, ProcessName, ahk_id %Hwnd%
		WinGetClass, CtrlName, ahk_id %Ctrl%
		Smooth := 0
		Loop, Parse, iniScrollSmooth, |
		{
			Resolution := 20
			Loop, Parse, A_LoopField, :
			{
				If(A_Index = 1){
					A_ProcessName := A_LoopField
				}Else{
					Resolution := ToFloat(A_LoopField, 20, 1, 120)
				}
			}
			If(ProcessName . "<" . CtrlName . ">" = A_ProcessName) | (ProcessName = A_ProcessName) | ("<" . CtrlName . ">" = A_ProcessName){
				Smooth := 1
				If(CtrlName = "sysListView32"){
					SendMessage, 4239, 0, 0, , ahk_id %Ctrl% ; LVM_GETVIEW
					If(ErrorLevel = 1) | (ErrorLevel = 3){
						Smooth := 0
					}
				}
				Break
			}
			If("?" = A_ProcessName){
				ToolTip, ProcessName = "%ProcessName%"`nControlClassName = "%CtrlName%", , , 2
			}
		}
		Thumb_ScrollStartPosY := PosY
		CounterY := 0
		If(Smooth = 1){
			CounterNotchY := 1 / Resolution
		}Else{
			CounterNotchY := 0.05
		}
		If(iniScrollShowWindow != 255){
			Thumb_TransparentOver(Hwnd, ProcessName)
		}
	}

	IfWinExist, ahk_id %Hwnd%
	{
		ThisTimerErr := TimerErr
		If(PrevTickCount != ""){
			ThisTimerErr := TickCountDiff(A_TickCount,PrevTickCount) / 10
		}
		PrevTickCount := A_TickCount
		OffsetY := Abs(PosY - Thumb_ScrollStartPosY)
		CounterY += Abs(OffsetY * (1 + iniScrollAcceleration) ** OffsetY * iniScrollVelocity * ThisTimerErr)
		Wheel := 0
		Loop{
			If(CounterY < CounterNotchY){
				Break
			}
			CounterY -= CounterNotchY
			If(Smooth != 1){
				CounterNotchY := 1
			}
			Wheel += CounterNotchY
		}
		If(Wheel <> 0){
			If(Wheel > 273){
				Wheel := 273
			}
			If(iniScrollVelocity < 0){
				Wheel *= -1
			}
			If(PosY < Thumb_ScrollStartPosY){
				Wheel *= -1
			}
			If(CtrlName = "sysListView32") & (Smooth = 1){
				SendMessage, 0x1014, 0, Round(Wheel * 24), , ahk_id %Ctrl% ; LVM_SCROLL
			}Else{
				SendMessage, 0x20A, Round(Wheel * -120) << 16, %lp%, , ahk_id %Ctrl% ; WM_MOUSEWHEEL
			}
		}
		If(Thumb_State != 1){
			SlowY := (PosY - Thumb_ScrollStartPosY) * (1 - (1 - iniScrollResistance) ** ThisTimerErr)
			SlowY += Thumb_ScrollStartPosY - Round(Thumb_ScrollStartPosY)
			Thumb_ScrollStartPosY := Round(Thumb_ScrollStartPosY)
			MouseMove, 0, -Round(SlowY), 0, R
			Thumb_ScrollStartPosY += SlowY - Round(SlowY)
		}
	}
}

Thumb_TransparentOver(Handle, ProcessName = ""){
	Global
	Local Count, A_Handle, Style, R_Index
	If(Handle != "Off"){
		Thumb_TransparentHwnd := 0
		If(ProcessName != "csrss.exe"){
			WinGet, Thumb_Handle, List
			Count := 0
			Loop, %Thumb_Handle%{
				A_Handle := Thumb_Handle%A_Index%
				If(Handle = A_Handle){
					Break
				}
				WinGet, Style, Style, ahk_id %A_Handle%
				If(Style & 0x14080000 = 0x14080000){
					Count++
					Thumb_TransparentHwnd := Count
					Thumb_TransparentHwnd%Count% := A_Handle
					WinSet, Trans, % 255 - iniScrollShowWindow ** (1 / Count) * 255, ahk_id %A_Handle%
					CriticalOff(30)
				}
			}
		}
	}Else{
		If(Thumb_TransparentHwnd != ""){
			Loop, %Thumb_TransparentHwnd%{
				R_Index := Thumb_TransparentHwnd - A_Index + 1
				A_Handle := Thumb_TransparentHwnd%R_Index%
				WinSet, Trans, Off, ahk_id %A_Handle%
				CriticalOff(30)
			}
			Thumb_TransparentHwnd := 0
		}
	}
}


Thumb_Activate(){
	Global
	SetTimer, Thumb_Unhook, Off
	Suspend, Off
}

Thumb_Deactivate(){
	Global
	SetTimer, Thumb_Unhook, Off
	SetTimer, Thumb_Unhook, % -MinusHalfTimerErr(iniUnhookDelay * 10)
}

Thumb_Unhook:
	Thumb_Unhook_Func()
 	Return

Thumb_Unhook_Func(){
	Global
	Local KeyPressed := 0
	If(Thumb_State = 0){
		Loop, %KeyCount%{
			If(DD_%A_Index% = 1) | (UP_%A_Index% = 0) & (GetKeyState(KKK_%A_Index%, "P")){
				KeyPressed := 1
			}
		}
		If(KeyPressed = 0){
			Suspend, On
		}Else{
			SetTimer, Thumb_TestKeyUp, Off
			SetTimer, Thumb_TestKeyUp, 10
		}
	}
}

IniReadInteger(File, Section, Key, Default, Min, Max){
	Local Res
	IniRead, Res, %File%, %Section%, %Key%, %Default%
	If Res Is Float
		Res := Round(Res)
	If Res Is Not Integer
		Res := Default
	If(Res < Min)
		Res := Min
	If(Res > Max)
		Res := Max
	Return Res * 1
}

IniReadFloat(File, Section, Key, Default, Min, Max){
	Local Res
	IniRead, Res, %File%, %Section%, %Key%, %Default%
	If Res Is Not Number
		Res := Default
	If(Res < Min)
		Res := Min
	If(Res > Max)
		Res := Max
	Return Res * 1
}

IniReadString(File, Section, Key, Default){
	Local Res
	IniRead, Res, %File%, %Section%, %Key%, %A_Tab%
	If(Res = A_Tab){
		Res := Default
	}
	Return Res
}


Newton_Init(){
	Global
	iniScanTime := IniReadFloat(fileNewton, "Inertia", "ScanTime", 9, 2, 999)
	iniErrVelocity := IniReadFloat(fileNewton, "Inertia", "Velocity", 1, 0, 999)
	iniInitialVelocity := IniReadFloat(fileNewton, "Inertia", "InitialVelocity", 0.6, 0, 999)
	iniInitialVelocityExp := IniReadFloat(fileNewton, "Inertia", "InitialVelocityExp", 1.05, 0, 5)
	iniAspectRatio := IniReadFloat(fileNewton, "Inertia", "AspectRatio", 1.1, 0.01, 100)
	iniErrMaxVelocity := IniReadFloat(fileNewton, "Inertia", "MaxVelocity", 40, 0, 999)
	iniErrResistance := IniReadFloat(fileNewton, "Inertia", "Resistance", 1.3, 0.01, 100) / 100
	iniReflection := IniReadFloat(fileNewton, "Inertia", "Reflection", -0.5, -1, 1)
	iniReflectionTangent := IniReadFloat(fileNewton, "Inertia", "ReflectionTangent", 0.8, 0, 1)
	iniShowVelocity := IniReadInteger(fileNewton, "Inertia", "ShowVelocity", 0, 0, 9999)

	MouseGetPos, Newton_OrgPosX, Newton_OrgPosY
	Newton_OrgTickCount := A_TickCount
	Newton_Velocity := 0
}

Newton_Reset(){
	SetTimer, Newton, Off
	SetTimer, Newton, 10
}


Newton: 
	Newton_RepeatProc()
	Return

Newton_RepeatProc(){
	Global
	Static PrevState
	Static SlowLevel
	Static ReflectionX
	Static ReflectionY
	Static RemainMoveX
	Static RemainMoveY
	Static VelocityX
	Static VelocityY
	Static Velocity
	Local PosX, PosY, TickCount, TempVelocity, MoveX, MoveY, ThisNum, Count, MinTickCount, TempFormat

	MouseGetPos, PosX, PosY
	TickCount := A_TickCount

	If(Thumb_State = 1){
		If(PrevState != 1){
			PrevState := 1
			Newton_Velocity := 0
		}

		If(TickCountDiff(TickCount, Newton_OrgTickCount) <= iniScanTime * 10){
			ThisNum := Newton_Velocity + 1
			Loop, %Newton_Velocity%
			{
				If(Newton_TickCount%A_Index% = "")
					| (TickCountDiff(TickCount, Newton_TickCount%A_Index%) > iniScanTime * 10)
					| (TickCountDiff(TickCount, Newton_TickCount%A_Index%) < 5){
					ThisNum := A_Index
					Newton_TickCount%A_Index% := ""
				}
			}
			If(ThisNum > Newton_Velocity){
				Newton_Velocity := ThisNum
			}
			Newton_VelocityX%ThisNum% := PosX - Newton_OrgPosX
			Newton_VelocityY%ThisNum% := PosY - Newton_OrgPosY
			Newton_TickCount%ThisNum% := Newton_OrgTickCount
		}
	}

	If(Thumb_State != 1){
		If(PrevState != 0){
			PrevState := 0
			VelocityX := 0
			VelocityY := 0
			Count := 0
			MinTickCount := Newton_OrgTickCount
			Loop, %Newton_Velocity%
			{
				If(Newton_TickCount%A_Index% != ""){
					Count++
					VelocityX += Newton_VelocityX%A_Index%
					VelocityY += Newton_VelocityY%A_Index%
					If(TickCountDiff(MinTickCount, Newton_TickCount%A_Index%) > 0){
						MinTickCount := Newton_TickCount%A_Index%
					}
				}
			}
			If(Count >= 1){
				VelocityX /= Count
				VelocityY /= Count
			}
			TimerErr := TickCountDiff(TickCount, MinTickCount) / (Count + 1) / 10

			iniVelocity := iniErrVelocity * TimerErr
			iniMaxVelocity := iniErrMaxVelocity * TimerErr
			iniResistance := (1 - (1 - iniErrResistance) ** TimerErr)

			Velocity := Sqrt(VelocityX ** 2 + VelocityY ** 2)
			If(iniShowVelocity > 0){
				TempFormat := A_FormatFloat
				SetFormat, Float, 0.1
				ToolTip, % Velocity / TimerErr, , , 3
				SetFormat, Float, %A_FormatFloat%
				SetTimer, Newton_HideToolTip, % -MinusHalfTimerErr(iniShowVelocity * 10)
			}
			If(Velocity > iniVelocity) & (iniMaxVelocity > 0){
				VelocityX *= Sqrt(iniAspectRatio)
				VelocityY /= Sqrt(iniAspectRatio)
				Velocity := Sqrt(VelocityX ** 2 + VelocityY ** 2)
				TempVelocity := (Velocity / iniMaxVelocity * iniInitialVelocity) ** iniInitialVelocityExp * iniMaxVelocity
				If(TempVelocity > iniMaxVelocity){
					TempVelocity := iniMaxVelocity
				}
				VelocityX *= TempVelocity / Velocity
				VelocityY *= TempVelocity / Velocity
				Velocity := TempVelocity
			}Else{
				Velocity := 0
				VelocityX := 0
				VelocityY := 0
			}

			SlowLevel := 1
			ReflectionX := 1
			ReflectionY := 1
			RemainMoveX := 0
			RemainMoveY := 0
		}

		MoveX := VelocityX * SlowLevel
		MoveY := VelocityY * SlowLevel

		If(PosX = 0) & (ReflectionX * MoveX < 0) | (PosX = A_ScreenWidth - 1) & (ReflectionX * MoveX > 0){
			ReflectionX *= iniReflection
			ReflectionY *= iniReflectionTangent
			RemainMoveX *= iniReflection
			RemainMoveY *= iniReflectionTangent
		}
		If(PosY = 0) & (ReflectionY * MoveY < 0) | (PosY = A_ScreenHeight - 1) & (ReflectionY * MoveY > 0){
			ReflectionX *= iniReflectionTangent
			ReflectionY *= iniReflection
			RemainMoveX *= iniReflectionTangent
			RemainMoveY *= iniReflection
		}
		MoveX *= ReflectionX
		MoveY *= ReflectionY

		If(Sqrt(MoveX ** 2 + MoveY ** 2) <= iniResistance){
			If(iniShowVelocity >= 0){
				ToolTip, , , , 3
			}
			SetTimer, Newton, Off
		}

		MoveX += RemainMoveX
		MoveY += RemainMoveY
		RemainMoveX := MoveX - Round(MoveX)
		RemainMoveY := MoveY - Round(MoveY)
		MoveX -= RemainMoveX
		MoveY -= RemainMoveY

		PosX += MoveX
		PosY += MoveY
		MouseMove, PosX, PosY, 0

		SlowLevel *= 1 - iniResistance
	}

	Newton_OrgPosX := PosX
	Newton_OrgPosY := PosY
	Newton_OrgTickCount := TickCount
}

Newton_HideToolTip:
	If(iniShowVelocity >= 0){
		ToolTip, , , , 3
	}
	Return

Thumb_SetState(State){
	Global
	Local temp
	If(Thumb_State = ""){
		Thumb_State := 0
	}
	temp := State << 4 | Thumb_State
	If(temp = 0x10){
		Thumb_State := 1
		Newton_Reset()
		Thumb_Activate()
		Liftless_Down()
	}Else If(temp = 0x01){
		Thumb_State := 0
		Thumb_Deactivate()
		Liftless_Up()
	}
}


Newton_End: