#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Example, remove a user

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
; we need to notify user if this fails; can't remove without active users!
_UAF_LoadAuthFile("example.auth")
If @error Then
	$message = "Loading example.auth failed. " & @LF
	$message &= "You can't remove users without creating some first!" & @LF & @LF
	$message &= "Try running UAFSample_Add_User and try again."
	MsgBox($MB_ICONHAND, "Loading failed", $message)
	Exit
EndIf

; get user input for a username:

Global $username

$username = InputBox("Username", "Enter username to remove")
If @error Then Exit

; remove user, (ignoring errors, such as no such user)
_UAF_RemoveUser($username)

; save the context back to example.auth (ignoring errors)
_UAF_SaveAuthFile("example.auth")
