#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Example, add a user (basic version)

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

; try to load an existing example.auth file (ignoring errors)
_UAF_LoadAuthFile("example.auth")

; get user input for a username and password:

Global $username, $password

$username = InputBox("Username", "Enter username")
If @error Then Exit

$message = "Enter password for user '" & $username & "'"
$password = InputBox("Password", $message, "", "*")
If @error Then Exit

; add the user, using the default hash / round count
; see UAFSample_Add_Users_Advanced for a more complex, custom hash/round example

_UAF_StoreUser($username, $password)
If @error Then
	MsgBox($MB_ICONHAND, "store error", "StoreUser error: " & @error)
EndIf

; save the context back to example.auth (ignoring errors)
_UAF_SaveAuthFile("example.auth")
