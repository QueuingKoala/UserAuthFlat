#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Example, verify a user

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.
#ce

; common language includes:
#include <Constants.au3>

; include the UAF Library:
#include "..\UserAuthFlat.au3"

Global $message

; initialize a blank context, in case loading below fails:
_UAF_InitAuthContext()

; try to load an existing example.auth file (exit on error)
; we need to notify user if this fails; can't verify without active users!
_UAF_LoadAuthFile("example.auth")
If @error Then
	$message = "Loading example.auth failed. " & @LF
	$message &= "You can't verify users without creating some first!" & @LF & @LF
	$message &= "Try running UAFSample_Add_User and try again."
	MsgBox($MB_ICONHAND, "Loading failed", $message)
	Exit
EndIf

; get user input for a username and password:

Global $username, $password

$username = InputBox("Username", "Enter username to verify")
If @error Then Exit

$message = "Enter password for user '" & $username & "'"
$password = InputBox("Password", $message, "", "*")
If @error Then Exit

; verify the user:
Global $verify_result, $error_code
$verify_result = _UAF_ValidateUser($username, $password)

$error_code = @error

; if we have success:
If $verify_result Then
	$message = "Successfully authenticated user: '" & $username & "'"
	MsgBox($MB_OK, "Validation Passed", $message)
	Exit
EndIf

; otherwise, we failed validation:
$message = "Failed to authenticate user: '" & $username & "'" & @LF
$message &= "Error code returned from _UAF_ValidateUser() is: " & $error_code
MsgBox($MB_ICONHAND, "Validation Failed", $message)
