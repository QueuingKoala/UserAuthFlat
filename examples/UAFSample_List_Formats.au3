#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: Example, list supported formats, hashes, & default rounds

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.
#ce

; common language includes:
#include <Constants.au3>

; include the UAF Library:
#include "..\UserAuthFlat.au3"

Global $message

; enumerate an array of supported formatID values:
Global $supported_formats = _UAF_EnumFormats()

; create a message to hold the results:
$message = "The following formats are supported:"

; cycle through supported formats, pulling display name and rounds:
Global $formatID, $hash_name, $round_count

For $i = 1 To $supported_formats[0]
	$formatID = $supported_formats[$i]
	$hash_name = _UAF_LookupDisplayByFormat($formatID)
	$round_count = _UAF_LookupRoundsByFormat($formatID)

	; add to message:
	$message &= @LF & "FormatID: " & $formatID
	$message &= " Display Name: " & $hash_name
	$message &= " Default Rounds: " & $round_count
Next

; add the 'best available' hash format to the end of the list.
; This is the default format used to store users when omitted.
$message &= @LF & @LF & "Best available FormatID: " & $_UAF_BEST_FORMAT

; show the results:
MsgBox($MB_OK, "Available UAF Formats", $message)
