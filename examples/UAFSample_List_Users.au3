#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Example, list users in Auth file

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.
#ce

; common language includes:
#include <Constants.au3>

; include the UAF Library:
#include "..\UserAuthFlat.au3"

Global $message

; try to load an existing example.auth file (exit on error)
; we need to notify user if this fails; can't list without active users!
_UAF_LoadAuthFile("example.auth")
If @error Then
	$message = "Loading example.auth failed. " & @LF
	$message &= "You can't list users without creating some first!" & @LF & @LF
	$message &= "Try running UAFSample_Add_User and try again."
	MsgBox($MB_ICONHAND, "Loading failed", $message)
	Exit
EndIf

; enumerate users into an array
Global $user_list = _UAF_EnumUsers()

; create a message to show users:
$message = "Number of users: " & $user_list[0]

; cycle through users, putting each one on a new line in the message:
For $i = 1 To $user_list[0]
	$message &= @LF & "Username: '" & $user_list[$i] & "'"
Next

; display the list:
MsgBox($MB_OK, "User list", $message)
