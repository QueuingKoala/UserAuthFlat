#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Generate timings for hashing features

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.

#ce

Opt("MustDeclareVars", True)

#include "..\UserAuthFlat.au3"

#include <Constants.au3>

Global $FORMAT_ARRAY = _UAF_EnumFormats()
Global $ROUND_TESTS = StringSplit("1,1000,5000,10000,20000", ",")

Global $timer, $output = ""
Global $user = "Person", $pass = "Password"
Global $formatID, $format_name, $rounds

_UAF_InitAuthContext()

For $i = 1 To $FORMAT_ARRAY[0]

	If StringLen($output) > 0 Then
		$output &= @LF
	EndIf

	$formatID = $FORMAT_ARRAY[$i]
	$format_name = _UAF_LookupDisplayByFormat($formatID)

	$output &= "Hash: " & $format_name

	For $k = 1 To $ROUND_TESTS[0]

		$rounds = $ROUND_TESTS[$k]

		; time store time
		$timer = TimerInit()
		_UAF_StoreUser($user, $pass, $formatID, $rounds)
		$timer = Round( TimerDiff($timer) / 1000, 2 )
		
		$output &= @LF & "  R: " & $rounds & " [store] " & $timer

		; time lookup time
		$timer = TimerInit()
		_UAF_ValidateUser($user, $pass)
		$timer = Round( TimerDiff($timer) / 1000, 2 )
		
		$output &= @LF & "  R: " & $rounds & " [check] " & $timer
	
	Next

Next

MsgBox($MB_OK, "Timings", $output)
