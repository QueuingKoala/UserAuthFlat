#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Verify a UAF user against a simple un/pw check file

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.

#ce

Opt("MustDeclareVars", True)
#NoTrayIcon
#NoAutoIt3Execute

#include "..\UserAuthFlat.au3"

#include <Constants.au3>

; exit codes:
Global $EXIT_SUCCESS		= 0		; passed authentication
Global $EXIT_FAIL			= 1		; failed authentication
Global $EXIT_PARAMS			= 2		; bad params passed
Global $EXIT_FILE_USER		= 3		; can't open input files, or badly formatted file
Global $EXIT_LOAD_AUTH		= 4		; can't load auth input file
Global $EXIT_LOG_FATAL		= 5		; set when fatal logging is requested and failed

; must get 2 params:
If $CmdLine[0] < 2 Then
	Exit $EXIT_PARAMS
EndIf

; define files from input:
Global $auth_file = $CmdLine[1]
Global $user_file = $CmdLine[2]

; get un/pw:

Global $handle = FileOpen($user_file, $FO_READ)
If $handle = -1 Then
	Exit $EXIT_FILE_USER
EndIf

Global $user = FileReadLine($handle)
Global $pass = FileReadLine($handle)
If @error OR StringLen($user) = 0 Then
	Exit $EXIT_FILE_USER
EndIf

FileClose($handle)

; load the auth file into UAF context:
_UAF_LoadAuthFile($auth_file)
If @error Then
	Exit $EXIT_LOAD_AUTH
EndIf

; validate user with supplied credentials, and store result:
Global $AUTH_STATUS = False
If _UAF_ValidateUser($user, $pass) Then
	$AUTH_STATUS = True
EndIf

; init logging based on status of UAF_VerifyByFile.ini, if present
Global $CONFIG_FILE = @ScriptDir & "\UAF_VerifyByFile.ini"
Global $LOG_HANDLE, $LOG_STATUS = False, $LOG_FATAL = False
Global $LOG_MSG_SUCCESS = "Successful auth for user: " & $user
Global $LOG_MSG_FAILURE = "Failed auth for user: " & $user
init_logging() ; will set $LOG_STATUS to true if all checks passed

; Record result to log (if enabled) and exit with the correct status:
If $AUTH_STATUS Then
	send_log( parse_env_vars($LOG_MSG_SUCCESS) )
	close_log_and_exit($EXIT_SUCCESS)
EndIf

send_log( parse_env_vars($LOG_MSG_FAILURE) )
close_log_and_exit($EXIT_FAIL)


; init_logging() - determine log status and set global log vars
Func init_logging()

	If "True" <> IniRead($CONFIG_FILE, "Logging", "Enabled", "False") _
	Then
		Return
	EndIf

	; get logfile
	Local $logfile = IniRead($CONFIG_FILE, "Logging", "Logfile", "")
	If StringLen($logfile) = 0 Then
		Return
	EndIf

	; determine if log failure is fatal to authenticating the user
	If "True" = IniRead($CONFIG_FILE, "Logging", "LogFatal", "False") _
	Then
		Global $LOG_FATAL = True
	EndIf

	; pull any custom log messages:
	Local $text
	$text = IniRead($CONFIG_FILE, "Logging", "TextSuccess", "")
	If StringLen($text) > 0 Then
		Global $LOG_MSG_SUCCESS = StringReplace($text, ":user:", $user)
	EndIf
	$text = IniRead($CONFIG_FILE, "Logging", "TextFailure", "")
	If StringLen($text) > 0 Then
		Global $LOG_MSG_FAILURE = StringReplace($text, ":user:", $user)
	EndIf

	; attempt to open logfile for writing
	FileChangeDir(@ScriptDir)
	Global $LOG_HANDLE = FileOpen($logfile, $FO_APPEND)
	If $LOG_HANDLE = -1 AND $LOG_FATAL Then
		Exit $EXIT_LOG_FATAL
	EndIf

	If $LOG_HANDLE <> -1 Then
		Global $LOG_STATUS = True
	EndIf

	Return

EndFunc

; send_log($string) - sends $string to open logfile
Func send_log($string)

	If NOT $LOG_STATUS Then
		Return
	EndIf

	Local $success
	Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " "
	$timestamp &= @HOUR & ":" & @MIN & ":" & @SEC & " "
	$success = FileWriteLine($LOG_HANDLE, $timestamp & $string)
	If NOT $success AND $LOG_FATAL Then
		FileClose($LOG_HANDLE)
		Exit $EXIT_LOG_FATAL
	EndIf

EndFunc

; close_log_and_exit($code) - close an open logfile (if present) and exit with $code
Func close_log_and_exit($code)
	
	If $LOG_STATUS Then
		FileClose($LOG_HANDLE)
	EndIf

	Exit $code

EndFunc

; parse_env_vars() - parse env-var declarations from a string
Func parse_env_vars($string)

	Local $loc1, $loc2, $env_var

	While True

		$loc1 = StringInStr($string, "%")
		$loc2 = StringInStr($string, "%", default, 2)
		If $loc2 = 0 Then ; no more replacements
			ExitLoop
		EndIf
		
		; get the env_var name and convert it:
		$env_var = StringMid($string, $loc1 + 1, $loc2 - ($loc1+1))
		$env_var = EnvGet($env_var)

		; replace that part of the input with the env_var value:
		$string = StringMid($string, 1, $loc1 - 1) & $env_var & _
			StringMid($string, $loc2 + 1)

	WEnd

	Return $string

EndFunc
