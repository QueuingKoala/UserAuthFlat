#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: generate testsuite auth files

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.

#ce

Opt("MustDeclareVars", True)

#include "..\UserAuthFlat.au3"

#include <Constants.au3>

Global $FILE_SIMPLE_AUTH = "basic.auth"
Global $FILE_FULL_AUTH = "auths\auth-cases.auth"

; pre-determined magic hash. THESE ARE NOT SECURE!!! NO PRNG DATA!!!
; we use them here for testing only, so all users can get the same testcase file
Global $MAGIC_HASH =	Binary("0xF00DF00DBEEFBEEF")
	$MAGIC_HASH &=		Binary("0x0123456789ABCDEF")

; open files:
Global $file_simple = FileOpen($FILE_SIMPLE_AUTH, $FO_OVERWRITE)
Global $file_full = FileOpen($FILE_FULL_AUTH, $FO_OVERWRITE)
If $file_simple = -1 OR $file_full = -1 Then
	MsgBox($MB_ICONHAND, "File open errror", "At least one file failed to open")
	Exit 1
EndIf

; get formatIDs:
Global $format_md5		= _UAF_LookupFormatByDisplay("MD5")
Global $format_sha1		= _UAF_LookupFormatByDisplay("SHA1")
Global $format_sha256	= _UAF_LookupFormatByDisplay("SHA-256")
Global $format_sha512	= _UAF_LookupFormatByDisplay("SHA-512")

_UAF_InitAuthContext()

; file_simple
FileWriteLine($file_simple, _
	sample_auth_line($format_sha512, 0, $MAGIC_HASH, "John", "Password") )
FileWriteLine($file_simple, _
	sample_auth_line($format_md5, 5000, $MAGIC_HASH, "Sam", "Password") )

; file_full:
FileWriteLine($file_full, _
	sample_auth_line($format_md5, 0, $MAGIC_HASH, "MD5", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_md5, 1, $MAGIC_HASH, "MD5_1", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_sha1, 0, $MAGIC_HASH, "SHA1", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_sha1, 1, $MAGIC_HASH, "SHA1_1", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_sha256, 0, $MAGIC_HASH, "SHA-256", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_sha256, 1, $MAGIC_HASH, "SHA-256_1", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_sha512, 0, $MAGIC_HASH, "SHA-512", "Password") )
FileWriteLine($file_full, _
	sample_auth_line($format_sha512, 1, $MAGIC_HASH, "SHA-512_1", "Password") )

; fake/bad hashes:
FileWriteLine($file_full, "")
FileWriteLine($file_full, "99:unknown:abYZ$fakehash")
FileWriteLine($file_full, "")
FileWriteLine($file_full, "badly:formatted:record:#1")
FileWriteLine($file_full, "badlyFormattedRecord#2")

; close files
FileClose($file_simple)
FileClose($file_full)

Func sample_auth_line($format, $rounds, $salt, $user, $pass)

	Local $alg = _UAF_LookupAlgByFormat($format)
	Local $line = $format

	; format/rounds to line:
	If $rounds = 0 Then
		$rounds = _UAF_LookupRoundsByFormat($format)
	Else
		$line &= "." & $rounds
	EndIf

	; user:
	$line &= ":" & $user

	; salt:
	$line &= ":" & $salt

	; hash:
	Local $hash = _UAF_PerformHashing($pass, $salt, $alg, $rounds)
	$line &= "$" & $hash

	Return $line

EndFunc
