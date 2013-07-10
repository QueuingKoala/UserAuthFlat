#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Example, add a user (advanced version)

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

; Define the desired hash and rounds to be used when storing the user.
; The display name is converted to a formatID, used by _UAF_StoreUser().
; You must define this to a supported hash format display name.

; sample values to try: MD5, SHA1, SHA-256, SHA-512
Global $HASH_NAME = "MD5"
; the default round count is set by hash, and usually is 1000
Global $ROUND_COUNT = 1500

; Convert the $HASH_NAME into a valid formatID:
Global $formatID = _UAF_LookupFormatByDisplay($HASH_NAME)
If @error Then
	MsgBox($MB_ICONHAND, "Invalid hash", "Hash not known: " & $HASH_NAME)
	Exit
EndIf

; add the user, using the defined formatID (hash) and number of rounds
; see UAFSample_Add_Users for a simpler example without the above settings

_UAF_StoreUser($username, $password, $formatID, $ROUND_COUNT)
If @error Then
	MsgBox($MB_ICONHAND, "store error", "StoreUser error: " & @error)
EndIf

; save the context back to example.auth (ignoring errors)
_UAF_SaveAuthFile("example.auth")
