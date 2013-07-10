#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: test suite for UserAuthFlat library external features

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.

#ce

Opt("MustDeclareVars", True)

#include "..\UserAuthFlat.au3"

#include <Constants.au3>

Global $q, $e, $x, $msg, $failCount = 0

; define desired tests:
Global $TEST_CLEAN_LOAD			= True
Global $TEST_STOCK_AUTH_FILE	= True
Global $TEST_LOAD_COUNT_INVALID	= True
Global $TEST_HASH_SUPPORT		= True
Global $TEST_UNKNOWN_HASH		= True
Global $TEST_VERIFY_CONTEXT		= True
GLobal $TEST_ENUM_USERS			= True
Global $TEST_STORE_USER			= True
Global $TEST_REMOVE_USER		= True
Global $TEST_SAVE_AND_VERIFY	= True

; define test returns based on auth test cases:
Global $_UAF_TESTVAL_ENUM_COUNT	= 9
Global $_UAF_TESTVAL_ENUM_FAIL	= 2

; define test files:
Global $TEST_FILE_BASIC_AUTH	= "basic.auth"
Global $TEST_FILE_CASES_AUTH	= "auths\auth-cases.auth"
Global $TEST_FILE_TEMP_AUTH		= "auths\auth-cases-save-test.auth"

If $TEST_VERIFY_CONTEXT Then		; initial verify context

	$q = _UAF_VerifyAuthContext()
	ExFail($q, "initial verify auth context")

EndIf

_UAF_LoadAuthFile($TEST_FILE_BASIC_AUTH)
Dim $e = @error, $x = @extended
If @error Then reportFail("load basic.auth", True)

If $TEST_VERIFY_CONTEXT Then		; verify context after load

	$q = _UAF_VerifyAuthContext()
	ExPass($q, "verify context after load")

EndIf

If $TEST_CLEAN_LOAD Then		; clean load without dropped lines

	ExPass($x = 0, "Count line failures in basic.auth; was expecting 0, got " & $x)

EndIf

If $TEST_STOCK_AUTH_FILE Then		; test stock auth.txt for expected values:

	$q = _UAF_ValidateUser("John", "Password")
	ExPass($q, "basic.auth John")

	$q = _UAF_ValidateUser("Sam", "Password")
	ExPass($q, "basic.auth Sam")

EndIf

If $TEST_VERIFY_CONTEXT Then		; unload context and verify

	_UAF_ReleaseAuthContext()

	$q = _UAF_VerifyAuthContext()
	ExFail($q, "unload context and verify")

EndIf

_UAF_LoadAuthFile($TEST_FILE_CASES_AUTH)
Dim $e = @error, $x = @extended
If @error Then reportFail("load auth-cases.auth", True)

If $TEST_LOAD_COUNT_INVALID Then		; bad record count on load

	ExPass($x = $_UAF_TESTVAL_ENUM_FAIL, _
		"Count line failures in auth-cases.auth; was expecting " & _
		$_UAF_TESTVAL_ENUM_FAIL & ", got " & $x)

EndIf

If $TEST_HASH_SUPPORT Then		; test validating each hash, each with 1/1000 rounds:

	ValidateSupportedFormats("Hash support from auth-cases.auth")

EndIf

If $TEST_UNKNOWN_HASH Then		; test unknown hash format:

	$q = _UAF_ValidateUser("unknown", "bogus")
	ExFail($q, "unsupported format")

EndIf

If $TEST_ENUM_USERS Then		; test user enumeration

	Global $array = _UAF_EnumUsers()
	$q = $array[0]
	ExPass($q = $_UAF_TESTVAL_ENUM_COUNT, _
		"EnumUsers count failure; was expecting " & $_UAF_TESTVAL_ENUM_COUNT & ", got " & $q)

EndIf

If $TEST_REMOVE_USER Then		; test removing a user

	$q = _UAF_RemoveUser("md5")
	$e = @error
	ExPass($q, "RemoveUser failure, @error = " & $e)

	; verify, expeciting failure
	$q = _UAF_ValidateUser("md5", "Password")
	ExFail($q, "RemoveUser and subsequent validation of removed user")

EndIf

If $TEST_STORE_USER Then		; test storing/validating a new user using default options

	$q = _UAF_StoreUser("StoreTest", "MyPassword")
	ExPass($q, "StoreUser using defaults")

	; validate it
	$q = _UAF_ValidateUser("StoreTest", "MyPassword")
	ExPass($q, "validate StoreUser using defaults")

EndIf

If $TEST_SAVE_AND_VERIFY Then	; test storing context to file and loading/verifying it

	; create an initial context using all available formats:
	_UAF_InitAuthContext()

	Global $formatList = _UAF_EnumFormats()
	Global $user, $password = "Password"
	Global $format, $store_rounds

	For $i = 1 To $formatList[0]

		$format = $formatList[$i]
		$user = _UAF_LookupDisplayByFormat($format)
		$q = _UAF_StoreUser($user, $password, $format)
			ExPass($q, "StoreUser " & $user)
		$store_rounds = 1
		$user &= "_1"
		$q = _UAF_StoreUser($user, $password, $format, $store_rounds)
			ExPass($q, "StoreUser " & $user)

	Next

	; Perform validation on newly created context:

	ValidateSupportedFormats("Hash support from _StoreUser")

	; save it to a file:

	$q = _UAF_SaveAuthFile($TEST_FILE_TEMP_AUTH)
	ExPass($q, "SaveAuthFile")

	; release context and load it from disk

	_UAF_ReleaseAuthContext()

	$q = _UAF_LoadAuthFile($TEST_FILE_TEMP_AUTH)
	ExPass($q, "LoadAuthFile from saved file")
	; and cleanup file now:
	FileDelete($TEST_FILE_TEMP_AUTH)

	; re-run validation on loaded state:

	ValidateSupportedFormats("Hash support from _StoreUser after a save/load")

EndIf


; END OF TEST SUITE
If $failCount > 0 Then Exit $failCount + 1
Exit 0

; Helper: validate all supported formats, with default and '*_1' user for single round:
Func ValidateSupportedFormats($msg_prefix ="", $password = "Password")

	Local $formatList = _UAF_EnumFormats()
	Local $user
	Local $format

	If StringLen($msg_prefix) > 0 Then
		$msg_prefix &= " "
	EndIf

	For $i = 1 To $formatList[0]

		$user = _UAF_LookupDisplayByFormat($formatList[$i])
		$q = _UAF_ValidateUser($user, $password)
			ExPass($q, $msg_prefix & "Validate stored user " & $user)
		$q = _UAF_ValidateUser($user, $password & "x")
			ExFail($q, $msg_prefix & "Validate stored user " & $user)

		$user &= "_1"
		$q = _UAF_ValidateUser($user, $password)
			ExPass($q, $msg_prefix & "Validate stored user " & $user)
		$q = _UAF_ValidateUser($user, $password & "x")
			ExFail($q, $msg_prefix & "Validate stored user " & $user)

	Next

EndFunc

; Helper: expected to pass
Func ExPass($t, $item = "[undefined]")
	If NOT $t Then reportFail("Failed ExPass for " & $item)
EndFunc

; Helper: expected to fail
Func ExFail($t, $item = "[undefined]")
	If $t Then reportFail("Failed ExFail for " & $item)
EndFunc

; generic failure reporting:
Func reportFail($msg, $fatal = False)

	;MsgBox($MB_ICONHAND, "Failure: ", $msg)
	ConsoleWrite("!Test Suite: " & $msg & @LF)

	If $fatal Then Exit 1

	$failCount += 1

EndFunc
