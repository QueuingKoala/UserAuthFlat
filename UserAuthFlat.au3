#cs LICENSING AND PURPOSE
vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: User authentication library with a flat-file backend

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.

#ce

#include-once
#include <Crypt.au3>
#include <Constants.au3>

; API Functions designed for external use ======================================
;
; _UAF_LoadAuthFile				-- Load a user-auth file into an array for query/update
; _UAF_SaveAuthFile				-- Save the context to an auth file on-disk
; _UAF_VerifyAuthContext		-- verify context is loaded and ready to query/update
; _UAF_ReleaseAuthContext		-- Invalidate the context to release in-memory storage
; _UAF_InitAuthContext			-- Reset the auth context to a valid but blank state
; _UAF_StoreUser				-- Store user credentials to the active context
; _UAF_RemoveUser				-- Remove a user entry from loaded context
; _UAF_RenameUser				-- Rename a user
; _UAF_ValidateUser				-- Validate a username & password against a loaded context
; _UAF_GetUserIndex				-- Externally useful to check for existance of user (use return as bool)
; _UAF_EnumUsers				-- Enumerate users by returning an array of loaded users
; _UAF_EnumFormats				-- return an array of supported formatIDs
; _UAF_LookupRoundsByFormat		-- Return the default rounds from a hash FormatID
; _UAF_LookupDisplayByFormat	-- Return a hash display name from a hash FormatID
; _UAF_LookupFormatByDisplay	-- Return the formatID from a provided hash display name
; _UAF_LookupAlgByFormat		-- (probably not useful externally, unless you have a strange usecase)
;
; Internal Functions NOT designed for external use =============================
;
; _UAF_VerifyAndAdd
; _UAF_AddToContext
; _UAF_CheckUserString
; _UAF_GenerateSalt
; _UAF_PerformHashing
; _UAF_XorSum
; _UAF_EnumHashes
; _UAF_EnumHashesAdd
; _UAF_LookupHelper
; _UAF_EnumBestFormat

; Internal-Use Global Variables ================================================
;
; $_UAF_ARRAY_CONTEXT - do NOT set this yourself - it is internal to this API
;   (as such, incorrect modification outside of API tools may cause issues)
;
; See remaining globals below.
; Limitation constants can be changed on a site-wide basis if needed.
; ==============================================================================

; Global (defined) error values potentially returned by external-use functions:
Global Const $_UAF_ERR_OK			= 0		; no error (ie: everything is okay)
Global Const $_UAF_ERR_CONTEXT		= 64	; no/invalid context is loaded
Global Const $_UAF_ERR_NOUSER		= 65	; invalid user specified
Global Const $_UAF_ERR_UNSUPPORTED	= 66	; passed Format ID is unsupported
Global Const $_UAF_ERR_CRYPTO		= 67	; unexpected crypto failure
Global Const $_UAF_ERR_ROUNDS		= 68	; rounds paramater passed was out of allowed range
Global Const $_UAF_ERR_BADCHAR		= 69	; bad character (ie: username has a disallowed character)
Global Const $_UAF_ERR_NOFILE		= 70	; specified file does not exist
Global Const $_UAF_ERR_FILEOPEN		= 71	; can't open specified file
Global Const $_UAF_ERR_FILESIZE		= 72	; file exceeds size limit
Global Const $_UAF_ERR_FILEWRITE	= 73	; file write error (ie: opened but subsequent write(s) failed)

; Global limitation constants:
Global Const $_UAF_DEF_ROUNDS_MIN	= 1
Global Const $_UAF_DEF_ROUNDS_MAX	= 20000
Global Const $_UAF_DEF_MB_LIMIT		= 2			; the max MiB input file we'll try to load
Global Const $_UAF_DEF_SALT_NWORDS	= 4			; salt size in 32-bit words

; Internal globals
Global Const $_UAF_OPT_NOCLOBBER	= False	; used to avoid clobbering of existing context

; Internal globals for _UAF_ARRAY_CONTEXT index refs:
Global Const $_UAF_REF_CON_DIMCOUNT	= 5		; number of elements in 2nd dimension
Global Const $_UAF_REF_CON_FORMAT	= 0
Global Const $_UAF_REF_CON_ROUNDS	= 1
Global Const $_UAF_REF_CON_USER		= 2
Global Const $_UAF_REF_CON_SALT		= 3
Global Const $_UAF_REF_CON_HASH		= 4

; Internal globals for _UAF_EnumHashes() index refs:
Global Const $_UAF_REF_HASH_DIMCOUNT	= 4		; number of elements in 2nd dimension
Global Const $_UAF_REF_HASH_FORMAT		= 0
Global Const $_UAF_REF_HASH_ID			= 1
Global Const $_UAF_REF_HASH_ROUNDS		= 2
Global Const $_UAF_REF_HASH_NAME		= 3

; Holds the 'best' available hash routine available to the local system:
Global Const $_UAF_BEST_FORMAT = _UAF_EnumBestFormat()

#cs _UAF_InitAuthContext()
	Purpose: Reset the auth context to a valid but blank state

	Usage: _UAF_InitAuthContext()

	Return: none
#ce
Func _UAF_InitAuthContext()

	_UAF_ReleaseAuthContext()	; required to drop any existing context
	Global $_UAF_ARRAY_CONTEXT[1][$_UAF_REF_CON_DIMCOUNT]

EndFunc

#cs _UAF_LoadAuthFile()

	Purpose: Load a user-auth file into an array for query/update

	Usage: _UAF_LoadAuthFile( $file )
		$file:	Filename path to an on-disk UAF auth file

	Return: [bool]
		On-Success: True, and sets @extended to number of dropped (bad) lines in the auth file.
		On-Fail: False, and sets @error as defined below

	@error/@extended:
		0:						Success; @extended contains lines not loaded
		$_UAF_ERR_NOFILE:		File doesn't exist
		$_UAF_ERR_FILEOPEN:		File open error
		$_UAF_ERR_FILESIZE:		File size too large

#ce
Func _UAF_LoadAuthFile($file)

	Local $fileHandle

	If NOT FileExists($file) Then
		Return SetError($_UAF_ERR_NOFILE, 0, False)
	EndIf

	; Don't process files over max file size as a saftey measure
	If FileGetSize($file) > 1024 ^ 2 * $_UAF_DEF_MB_LIMIT Then
		Return SetError($_UAF_ERR_FILESIZE, 0, False)
	EndIf

	$fileHandle = FileOpen($file, $FO_READ)
	If $fileHandle = -1 Then
		Return SetError($_UAF_ERR_FILEOPEN, 0, False)
	EndIf

	; Initialize / clear the loaded context:
	_UAF_InitAuthContext()

	; read in input lines and pass them to _VerifyAndAdd()

	Local $line, $discardCount = 0

	While True

		$line = FileReadLine($fileHandle)
		If @error Then ExitLoop

		_UAF_VerifyAndAdd($line)
		If @error Then
			$discardCount += 1
		EndIf
		; debug here on @error/@extended if you need to see why parsing failed

	WEnd

	FileClose($fileHandle)

	Return SetExtended($discardCount, True)

EndFunc

#cs _UAF_SaveAuthFile()

	Purpose: Save the context to an auth file on-disk

	Usage: _UAF_SaveAuthFile( $filename )
		$filename:	Path to on-disk filename to save to. Will overwrite the file (with valid permissions.)

	Return: [bool]
		On-Success: True, and may set @error in event of post-open output failures (see notes)
		On-Fail:	False, and sets @error

	Notes:
		True is returned if the file was opened for write but 1 or more entries failed to be.
			- this could mean all of them failed, so check @error/@extended if you care about this state.
			This only happens if we successfully opened the output for writing, but actual writes failed,
			such as in the case with a full disk or similar issue.

	@error:
		0:						Success
		$_UAF_ERR_FILEWRITE:	Partial failure: @extended holds lines that failed to write
									(note that this could be all of them)
		$_UAF_ERR_FILEOPEN:		File open error: could not open for writing
		$_UAF_ERR_CONTEXT:		Context not loaded

#ce
Func _UAF_SaveAuthFile($filename)

	Local $fileHandle

	; context check
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, False)
	EndIf

	; try to obtain a writable file handle, starting a blank file
	$fileHandle = FileOpen($filename, $FO_OVERWRITE)
	If $fileHandle = -1 Then
		Return SetError($_UAF_ERR_FILEOPEN, 0, False)
	EndIf

	Local $line, $formatID, $rounds, $user, $salt, $hash
	Local $failCount = 0

	; Cycle through active context, saving each entry as a line:

	For $i = 1 To UBound($_UAF_ARRAY_CONTEXT) - 1

		$line = ""

		; shorter local vars to use
		$formatID = $_UAF_ARRAY_CONTEXT[$i][$_UAF_REF_CON_FORMAT]
		$rounds = $_UAF_ARRAY_CONTEXT[$i][$_UAF_REF_CON_ROUNDS]
		$user = $_UAF_ARRAY_CONTEXT[$i][$_UAF_REF_CON_USER]
		$salt = $_UAF_ARRAY_CONTEXT[$i][$_UAF_REF_CON_SALT]
		$hash = $_UAF_ARRAY_CONTEXT[$i][$_UAF_REF_CON_HASH]

		; begin forming the output line:

		$line &= $formatID

		; If $rounds is not 0 (the enum default) we add it to the format spec
		; No bounds checking is done because context-inserting code has already checked it

		If $rounds > 0 Then
			$line &= "." & $rounds
		EndIf

		$line &= ":" & $user
		$line &= ":" & $salt
		$line &= "$" & $hash

		If NOT FileWriteLine($fileHandle, $line) Then
			$failCount += 1
		EndIf

	Next

	FileClose($fileHandle)

	; with a $failCount > 0, return is True (success opening file for write) with @error set
	If $failCount > 0 Then
		Return SetError($_UAF_ERR_FILEWRITE, $failCount, True)
	EndIf

	Return True

EndFunc

#cs _UAF_ReleaseAuthContext()
	Purpose: Invalidate the context to release in-memory storage

	Usage: _UAF_ReleaseAuthContext()

	Return: none
#ce
Func _UAF_ReleaseAuthContext()

	Global $_UAF_ARRAY_CONTEXT = ""

EndFunc

#cs _UAF_VerifyAuthContext()
	Purpose: verify context is loaded and ready to query/update

	Return: [bool]
		False: when context is not loaded
		True: when context is loaded
#ce
Func _UAF_VerifyAuthContext()

	If NOT IsDeclared("_UAF_ARRAY_CONTEXT") Then Return False
	If NOT IsArray($_UAF_ARRAY_CONTEXT) Then Return False

	If UBound($_UAF_ARRAY_CONTEXT, 0) <> 2 Then Return False
	If UBound($_UAF_ARRAY_CONTEXT, 2) <> $_UAF_REF_CON_DIMCOUNT Then Return False

	Return True

EndFunc

#cs _UAF_StoreUser()

	Purpose: Store user credentials to the active context

	Usage: _UAF_StoreUser( $user, $password [, $formatID [, $rounds ]] )
		$user:			username string. May not be blank.
		$password:		password string. May be blank.
		[$formatId]:	Optional, the hash FormatId to use to perform the hashing.
			* If undefined, defaults to $_UAF_BEST_FORMAT for the detected 'best' option
		[$rounds]:		Optional, number of rounds to hash with (integer >0)
			* If omitted or set to a value under 1, the format default is used.

	Return: [bool]
		On-Success:	True
		On-Fail:	False, and sets @error

	@error/@extended:
		$_UAF_ERR_CONTEXT		UAF Context unavailble
		$_UAF_ERR_UNSUPPORTED	Invalid format
		$_UAF_ERR_CRYPTO		unexpected crypto failure
		$_UAF_ERR_ROUNDS		rounds value out of allowable range
		$_UAF_ERR_NOUSER		User is empty
		$_UAF_ERR_BADCHAR		User contains disallowed character

#ce
Func _UAF_StoreUser($user, $password, $formatId = $_UAF_BEST_FORMAT, $rounds = 0)

	Local $alg, $salt, $rounds_enum

	; context check:
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, False)
	EndIf

	; $user can't be empty:
	If StringLen($user) < 1 Then
		Return SetError($_UAF_ERR_NOUSER, 0, False)
	EndIf

	; verify $user doesn't have disallowed chars:
	If NOT _UAF_CheckUserString($user) Then
		Return SetError($_UAF_ERR_BADCHAR, 0, False)
	EndIf

	; get hash alg:
	Local $alg = _UAF_LookupAlgByFormat($formatId)
	If @error Then
		Return SetError($_UAF_ERR_UNSUPPORTED, 0, False)
	EndIf

	; Pull rounds if not declared:
	If $rounds < 1 Then

		$rounds = 0		; force 0 to prevent bad callers using <1 non-zero values
		$rounds_enum = _UAF_LookupRoundsByFormat($formatId)
		If @error Then
			Return SetError($_UAF_ERR_UNSUPPORTED, 0, False)
		EndIf

	; Otherwise, verify sanity of passed rounds, then use it as the enumerated value:
	Else

		If $rounds < $_UAF_DEF_ROUNDS_MIN OR _
		$rounds > $_UAF_DEF_ROUNDS_MAX OR _
		Int($rounds) <> $rounds Then
			Return SetError($_UAF_ERR_ROUNDS, 0, False)
		EndIf

		$rounds_enum = $rounds

	EndIf

	; generate salt and hash

	Local $hash
	Local $salt = _UAF_GenerateSalt()

	$hash = _UAF_PerformHashing($password, $salt, $alg, $rounds_enum)
	If @error Then
		Return SetError($_UAF_ERR_CRYPTO, 0, False)
	EndIf

	$password = ""

	; Add it to the existing context:
	Return _UAF_AddToContext($formatId, $rounds, $user, $salt, $hash)

EndFunc

#cs _UAF_RemoveUser() - remove a user from context
	Purpose:
		Remove a user entry from loaded context

	Usage: _UAF_RemoveUser( $username )
		$username:	String, name of user to remove

	Return:
		On-Success: True
		On-Fail: False, and sets @error

	@error:
		$_UAF_ERR_CONTEXT:		context not loaded
		$_UAF_ERR_NOUSER:		no such user to remove
#ce
Func _UAF_RemoveUser($username)

	; check for loaded context:
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, False)
	EndIf

	; get the user context index location:
	Local $userIndex = _UAF_GetUserIndex($username)
	If @error Then
		Return SetError($_UAF_ERR_NOUSER, 0, False)
	EndIf

	; drop the row, shifting the others up:

	Local $row_max = UBound($_UAF_ARRAY_CONTEXT) - 1
	Local $col_max = UBound($_UAF_ARRAY_CONTEXT, 2) - 1
	Local $rowID, $colID

	For $rowID = $userIndex + 1 To $row_max
		For $colID = 0 To $col_max
			$_UAF_ARRAY_CONTEXT[$rowID - 1][$colID] = $_UAF_ARRAY_CONTEXT[$rowID][$colID]
		Next
	Next

	; then shrink the array

	; re-use $row_max, since it's now the new dimcount
	ReDim $_UAF_ARRAY_CONTEXT[$row_max][$_UAF_REF_CON_DIMCOUNT]

	Return True

EndFunc

#cs _UAF_RenameUser() - rename a user
	Purpose:
		Rename a user
	
	Usage: _UAF_RenameUser( $username, $new_username )
	
	Return:
		On-Success: True
		On-Fail: False, and sets @error

	@error:
		$_UAF_ERR_CONTEXT:		context not loaded
		$_UAF_ERR_NOUSER:		no such user to rename
		$_UAF_ERR_BADCHAR:		bad character in $newname
#ce
Func _UAF_RenameUser($user, $newname)

	Local $row_id

	; context check:
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, False)
	EndIf

	$row_id = _UAF_GetUserIndex($user)
	If @error Then
		Return SetError($_UAF_ERR_NOUSER, 0, False)
	EndIf

	If NOT _UAF_CheckUserString($newname) Then
		Return SetError($_UAF_ERR_BADCHAR, 0, False)
	EndIf

	; perform rename:
	$_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_USER] = $newname

	Return True

EndFunc

#cs _UAF_ValidateUser()
	Purpose: Validate a username & password against a loaded context

	Usage: _UAF_ValidateUser( $user, $password )
		$user:		Username to verify
		$password:	User's password to verify

	Return: [bool]
		On-Pass: True (password matches)
		On-Fail: False (password doesn't match or error encountered and enumerated in @error)

	@error/@extended On-Fail:
		0/0:					No error (ie: password provided was invalid when returning False)
		$_UAF_ERR_CONTEXT:		Auth context is not loaded ($_UAF_ERR_CONTEXT)
		$_UAF_ERR_NOUSER:		User not found in loaded context ($_UAF_ERR_NOUSER)
		$_UAF_ERR_UNSUPPORTED:	Function not supported ($_UAF_ERR_UNSUPPORTED)
#ce
Func _UAF_ValidateUser($user, $pass)

	Local $userContextID, $pass_hash, $hash, $alg, $rounds, $format, $salt

	; context check:
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, False)
	EndIf

	; try to find user in loaded context
	Local $userIndex = _UAF_GetUserIndex($user)
	If @error Then
		Return SetError($_UAF_ERR_NOUSER, 0, False)
	EndIf

	; pull user's details from loaded context:

	$salt = $_UAF_ARRAY_CONTEXT[$userIndex][$_UAF_REF_CON_SALT]
	$rounds = $_UAF_ARRAY_CONTEXT[$userIndex][$_UAF_REF_CON_ROUNDS]
	$hash = $_UAF_ARRAY_CONTEXT[$userIndex][$_UAF_REF_CON_HASH]
	$format = $_UAF_ARRAY_CONTEXT[$userIndex][$_UAF_REF_CON_FORMAT]

	$alg = _UAF_LookupAlgByFormat($format)
	If @error Then
		Return SetError($_UAF_ERR_UNSUPPORTED, @error, False)
	EndIf

	; Enumerate rounds if required:
	If $rounds = 0 Then

		$rounds = _UAF_LookupRoundsByFormat($format)
		If @error Then
			Return SetError($_UAF_ERR_UNSUPPORTED, @error, False)
		EndIf

	EndIf

	; run user pass/salt through hash specified by context for discovered user
	$pass_hash = _UAF_PerformHashing($pass, $salt, $alg, $rounds)

	; final validation check:

	If $pass_hash = $hash Then
		Return True
	EndIf

	Return False

EndFunc

#cs _UAF_EnumUsers()

	Purpose: Enumerate users by returning an array of loaded users

	Usage: _UAF_EnumUsers()

	Return:
		On-Success: returns an array of users, with array[0] the user total count
		On-Failure: returns an array of [-1], and sets @error

		@error:
			$_UAF_ERR_CONTEXT: Invalid context
#ce
Func _UAF_EnumUsers()

	; default return in the event of pre-enumeration errors:
	Local $user_array[1] = [-1]

	; context check:
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, $user_array)
	EndIf

	; add each user from loaded context:

	Local $user_count = UBound($_UAF_ARRAY_CONTEXT) - 1
	ReDim $user_array[$user_count + 1]

	For $i = 1 To $user_count
		$user_array[$i] = $_UAF_ARRAY_CONTEXT[$i][$_UAF_REF_CON_USER]
	Next

	; set element 0 to the user count:
	$user_array[0] = $user_count

	Return $user_array

EndFunc

#cs _UAF_EnumFormats()
	Purpose: return an array of supported formatIDs
		* Further enumeration can be done by the _UAF_Lookup*ByFormat() functions

	Usage: _UAF_EnumFormats()
		* (no params)

	Return:
		array of format IDs supported on running system

	Notes:
		$return[0] contains the number of hashes;
		$return[1] through $return[n] contain the formatIDs
#ce
Func _UAF_EnumFormats()

	; enumearte hash features to local var:
	Local $enum_hashAPI = _UAF_EnumHashes()

	; initalize return array based on available hash size:
	Local $bound = UBound($enum_hashAPI)
	Local $formatList[$bound]
	$formatList[0] = $bound - 1


	; add each formatID to the array:

	For $i = 1 To $bound - 1
		$formatList[$i] = $enum_hashAPI[$i][$_UAF_REF_HASH_FORMAT]
	Next

	Return $formatList

EndFunc

#cs _UAF_Lookup*By*() functions
	Purpose: Enumerate hash function usage details by Format ID

	Usage: _UAF_Lookup*ByFormat( $formatID )
		$formatID: 	FormatID to cross-reference
	
	Usage: _UAF_LookupFormatByDisplay( $hash_display_name )
		$hash_display_name: Display name of hash

	Return: CALG_ID, Rounds, DisplayName, or FormatID, depending on function called
	Return-On-Fail: 0 and sets @error:

	@error:
		1: match not found for specified search input
#ce
Func _UAF_LookupAlgByFormat($id)
	Local $ret = _UAF_LookupHelper($id, $_UAF_REF_HASH_FORMAT, $_UAF_REF_HASH_ID)
	Return SetError(@error, @extended, $ret)
EndFunc
; cont'd
Func _UAF_LookupRoundsByFormat($id)
	Local $ret = _UAF_LookupHelper($id, $_UAF_REF_HASH_FORMAT, $_UAF_REF_HASH_ROUNDS)
	Return SetError(@error, @extended, $ret)
EndFunc
; cont'd
Func _UAF_LookupDisplayByFormat($id)
	Local $ret = _UAF_LookupHelper($id, $_UAF_REF_HASH_FORMAT, $_UAF_REF_HASH_NAME)
	Return SetError(@error, @extended, $ret)
EndFunc
; cont'd
Func _UAF_LookupFormatByDisplay($id)
	Local $ret = _UAF_LookupHelper($id, $_UAF_REF_HASH_NAME, $_UAF_REF_HASH_FORMAT)
	Return SetError(@error, @extended, $ret)
EndFunc

; *****************************************************
;
; ****     INTERNAL FUNCTIONS BELOW THIS POINT     ****
;
; *****************************************************

#cs _UAF_LookupByFormatHelper() - [INTERNAL] helper lookup abstractor
	Purpose: Helper func to _UAF_Lookup*By*() functions

	Usage: _UAF_LookupByFormatHelper( $key_value, $src_index_ref, $dst_index_ref )
		$key_value:		Value to match on in the $src_index_ref
		$src_index_ref:	column index reference for the source ($key_value) data
		$dst_index_ref:	column index reference for the desired return

	Return: Varies, depending on target lookup

	@error:
		1:	match not found
#ce
Func _UAF_LookupHelper($id, $src, $dst)

	; enumeate hash features to local var:
	Local $enum_hashAPI = _UAF_EnumHashes()

	; hunt through the hash array for the requested match:

	For $i = 1 To UBound($enum_hashAPI) - 1

		If $id = $enum_hashAPI[$i][$src] Then
			Return $enum_hashAPI[$i][$dst]
		EndIf

	Next

	; not found
	Return SetError(1, 0, 0)

EndFunc

#cs _UAF_VerifyAndAdd() - [INTERNAL] helper to parse raw input lines
	Purpose: internal function to verify an auth line and add it to the array

	@error/@extended:
		1/#		Input contains incorrect field count (count in @ext)
		2/0		Format field is invalid
		3/0		User field is blank
		3/1		User matches prior entry
		4/0		Hash field is empty/malformed
		4/1		Hash field contains blank salt
		4/2		Hash field contains blank hash
		$_UAF_ERR_ROUNDS		Rounds field invalid
#ce
Func _UAF_VerifyAndAdd($input)

	Local $formatID, $rounds, $salt, $hash
	Local $format, $user, $salt_hash

	; **** BEGIN: general input validation

	If StringLen($input) = 0 Then Return True

	; check for and store the 3 primary fields:
	Local $split = StringSplit($input, ":")
	If $split[0] <> 3 Then
		Return SetError(1, $split[0], False)
	EndIf

	$format = $split[1]
	$user = $split[2]
	$salt_hash = $split[3]

	; **** BEGIN: format validation

	; the format is optionally split by a '.' char to denote non-default rounds:

	Local $format_split = StringSplit($format, ".")
	$formatID = $format_split[1]

	; $formatID may not be blank
	If StringLen($formatID) = 0 Then
		Return SetError(2, 0, False)
	EndIf

	; $rounds defaults to 0, which enumerates from hash defaults when required later
	$rounds = 0

	; if a 2nd value was after the $format_split, verify rounds sanity, then set it explicitly:

	If $format_split[0] >= 2 Then

		; if the rounds value falls outside min/max sanity range, return the error to the caller:
		If $format_split[2] < $_UAF_DEF_ROUNDS_MIN OR $format_split[2] > $_UAF_DEF_ROUNDS_MAX Then
			Return SetError($_UAF_ERR_ROUNDS, 0, False)
		EndIf

		$rounds = $format_split[2]

	EndIf

	; **** BEGIN: user validation

	If StringLen($user) = 0 Then Return SetError(3, 0, False)

	; **** BEGIN: salt/hash validation

	Local $salt_hash_split = StringSplit($salt_hash, "$")

	; define salt & hash, making sure they have data:

	If $salt_hash_split[0] <> 2 Then Return SetError(4, 0, False)
	$salt = $salt_hash_split[1]
	If StringLen($salt) = 0 Then Return SetError(4, 1, False)
	$hash = $salt_hash_split[2]
	If StringLen($hash) = 0 Then Return SetError(4, 2, False)

	; **** BEGIN: Put all data into a new row in the array:

	_UAF_AddToContext($formatID, $rounds, $user, $salt, $hash, $_UAF_OPT_NOCLOBBER)
	If @error Then Return SetError(3, 1, False)

	Return True

EndFunc

#cs _UAF_AddToContext() - [INTERNAL] add an entry to loaded context

	Purpose: Add a row to the context array

	Usage: _UAF_AddToContext( $formatID, $rounds, $user, $salt, $hash [, $clobber ] )
		$formatID:	Internal formatID value to enumerate desired hashing
		$rounds:	Either '0' to use the format's defined default, or an explicit >0 int of rounds
		$user:		Username
		$salt:		Texual salt
		$hash:		Texual hash string
		$clobber:	[Optional.] Defaults to True. When false, will ignore a duplicate user. Otherwise,
						the new entry will overwrite the old one in loaded context.

	Return: [bool]
		On-Success:	True
		On-Fail:	False, and sets @error

	@error/@extended:
		$UAF_ERR_CONTEXT:	Context not loaded
		1: 					User exists and $clobber = False

	Warning: besides context check, no value checking is done beyond a user search.
		Callers are responsible for any additonal checks.

#ce
Func _UAF_AddToContext($formatID, $rounds, $user, $salt, $hash, $clobber = True)

	Local $row_id
	Local $matched = False

	; context check:
	If NOT _UAF_VerifyAuthContext() Then
		Return SetError($_UAF_ERR_CONTEXT, 0, False)
	EndIf

	; Search through existing context to see if we have a user match.
	; What we do on such a match depends on $clobber

	$row_id = _UAF_GetUserIndex($user)
	$matched = NOT @error	; inverted here because a clean @error return means we DID match the user

	If $matched AND NOT $clobber Then
		Return SetError(1, 0, False)
	EndIf

	; if the user didn't exist, extend the context before adding:
	If NOT $matched Then
		$row_id = UBound($_UAF_ARRAY_CONTEXT)
		ReDim $_UAF_ARRAY_CONTEXT[$row_id + 1][$_UAF_REF_CON_DIMCOUNT]
	EndIf

	; add data to the row:
	$_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_FORMAT]	= $formatID
	$_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_ROUNDS]	= $rounds
	$_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_USER]	= $user
	$_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_SALT]	= $salt
	$_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_HASH]	= $hash

	Return True

EndFunc

#cs _UAF_GetUserIndex() - [INTERNAL] provide an index to a user by name
	Purpose:
		Return a $_UAF_ARRAY_CONTEXT row index to a user matching the input name

	Usage: _UAF_GetUserIndex( $username )

	Return: [int]
		On-Match:	array row index value (>=1, <= UBound($_UAF_ARRAY_CONTEXT) -1)
		On-Fail:	0, sets @error

	@error:
		On-Fail: 1
#ce
Func _UAF_GetUserIndex($username)

	Local $row_id

	For $row_id = 1 To UBound($_UAF_ARRAY_CONTEXT) - 1
		If $username = $_UAF_ARRAY_CONTEXT[$row_id][$_UAF_REF_CON_USER] Then
			Return $row_id
		EndIf
	Next

	; no user match, so return 0 with @error=1:
	Return SetError(1, 0, 0)

EndFunc

#cs _UAF_PerformHashing() - [INTERNAL] - Hashing helper, proxy to _Crypt_HashData() from Crypt.au3

	Purpose: taks password + salt and returns the hashed value

	Usage: _UAF_PerformHashing( $pass, $salt, $alg, $rounds )
		$pass:		User password
		$salt:		User salt
		$alg:		ALG_ID to use when hashing
			[ref]: http://msdn.microsoft.com/en-us/library/windows/desktop/aa375549(v=vs.85).aspx
		$rounds:	number of hashing rounds (no enumeration is done; callers must do so)

	Return: [string]
		On-Success: Return an ANSI string containing the hex-represented hash output
		On-Error: Returns -1, and sets @error/@extended as defined below:

		@error: (set On-Error)
			1: Call to _Crypt_HashData failed (its @error is passed on via @extended)
			2: Unexpected error performing XOR operation

		@extended: (set On-Error)
			contains the error code from the function referred to in @error


	Notes:
		* Does not do any verification that $alg or $rounds are sane.
#ce
Func _UAF_PerformHashing($pass, $salt, $alg, $rounds)

	; Init crypto to speed things up by creating a context
	_Crypt_Startup()

	; Use salt as IV by hasing it:
	Local $hash = _Crypt_HashData($salt, $alg)
	If @error Then
		Return SetError(1, @error, -1)
	EndIf

	; hash for requested number of rounds:
	Local $newhash
	For $i = 1 To $rounds
		$newhash = _Crypt_HashData(Binary($pass) & $hash, $alg)
		If @error Then
			Return SetError(1, @error, -1)
		EndIf

		; xorsum old & new hash:
		$hash = _UAF_XorSum($hash, $newhash)
		If @error Then
			Return SetError(2, @error, -1)
		EndIf
	Next

	_Crypt_Shutdown()

	; $hash is binary, so cast it to string and rip out the '0x' in front:
	$hash = StringMid( String($hash), 3)

	Return $hash

EndFunc

#cs _UAF_XorSum() - [INTERNAL]

	Purpose: performs a XOR-sum on input data, operation on 32-bit words from each input

	Usage: _UAF_XorSum( $data1, $data2 )
		Values are treated as binary, must both match sizes, and be a 4-byte multiple

	Return: [binary]
		On-Success: Returns the binary result of the stream XOR
		On-Fail: Returns an empty string (null binary data), and sets @error

	@error:
		1: input data doesn't match
		2: input not a 4-byte multiple
#ce
Func _UAF_XorSum($data1, $data2)

	; data must be equal-length and divisable by 32-bis/4-bytes:
	If BinaryLen($data1) <> BinaryLen($data2) Then
		Return SetError(1, 0, "")
	ElseIf Mod( BinaryLen($data1), 4 ) <> 0 Then
		Return SetError(2, 0, "")
	EndIf

	Local $int1, $int2
	Local $result = Binary("0x")

	; read in 4-byte blocks, xor, and append to output
	For $i = 1 To BinaryLen($data1) Step 4
		$int1 = BinaryMid($data1, $i, 4)
		$int2 = BinaryMid($data2, $i, 4)
		$result &= Binary( BitXOR($int1, $int2) )
	Next

	Return $result

EndFunc

#cs _UAF_EnumHashes() - [INTERNAL]
	Purpose: Enumerate supported hash functions and their required values through these APIs

	Usage: _UAF_EnumHashes()
		* (no params)

	Return: n x 3 array, with first row ignored:
		0) Numeric format ID
		1) CALG_ID
		2) Default rounds
		3) Hash Display Name

	@extended is set to the strongest format ID available

#ce
Func _UAF_EnumHashes()

	Local $best_id

	Local $array[1][$_UAF_REF_HASH_DIMCOUNT]

	; declare hashes Crypto.au3 doesn't have:
	Local Const $CALG_SHA256 = 0x0000800c
	Local Const $CALG_SHA384 = 0x0000800d
	Local Const $CALG_SHA512 = 0x0000800e

	; Add universally supported hash functions:
	_UAF_EnumHashesAdd($array, 1, $CALG_MD5, 1000, "MD5")
	$best_id = _UAF_EnumHashesAdd($array, 2, $CALG_SHA1, 1000, "SHA1")

	; If running on < XP SP2, return the limited hash support only
	If @OSVersion = "WIN2000" Then
		Return SetExtended($best_id, $array)
	EndIf

	; also return now if XP is not at SP2 or SP3:
	If StringInStr(@OSVersion, "WIN_XP") _
		AND @OSServicePack <> "Service Pack 3" _
		AND @OSServicePack <> "Service Pack 2" Then
			Return SetExtended($best_id, $array)
	EndIf

	; otherwise, add SHA-2 support:
	_UAF_EnumHashesAdd($array, 3, $CALG_SHA256, 1000, "SHA-256")
	$best_id = _UAF_EnumHashesAdd($array, 4, $CALG_SHA512, 1000, "SHA-512")

	Return SetExtended($best_id, $array)

EndFunc

#cs _UAF_EnumHashesAdd() - [INTERNAL]
	Purpose: helper-function to _UAF_EnumHashes()
		* Add supported WinAPI hashes to the enumeration array
#ce
Func _UAF_EnumHashesAdd(ByRef $array, $id, $calg_id, $rounds, $name)

	Local $dims = UBound($array)
	ReDim $array[$dims + 1][$_UAF_REF_HASH_DIMCOUNT]

	$array[$dims][$_UAF_REF_HASH_FORMAT]	= $id
	$array[$dims][$_UAF_REF_HASH_ID]		= $calg_id
	$array[$dims][$_UAF_REF_HASH_ROUNDS]	= $rounds
	$array[$dims][$_UAF_REF_HASH_NAME]		= $name

	; we return $id so the caller can assign it as the "best" option if desired:
	Return $id

EndFunc

#cs _UAF_EnumBestFormat() - [INTERNAL]
	Purpose: returns the best Format ID available to the local system
		* This is determined dynamically at runtime depending on supported hashes,
			and defined 'best' hashes available at each supporting check.
#ce
Func _UAF_EnumBestFormat()

	_UAF_EnumHashes()

	Return @extended

EndFunc

#cs _UAF_CheckUserString() - [INTERNAL] Verify correctness of a username string
	Purpose: verify username matches required structure rules

	Usage: _UAF_CheckUserString( $user )
		$user: username string to check
	
	Return:
		On-Pass: True
		On-Fail: False, sets @error to 1
#ce
Func _UAF_CheckUserString($user)

	Local $bad_chars[3] = [":", @LF, @CR]

	For $i =0 To UBound($bad_chars) - 1
		If StringInStr($user, $bad_chars[$i]) Then
			Return SetError(1, 0, False)
		EndIf
	Next

	Return True

EndFunc

#cs _UAF_GenerateSalt() - [INTERNAL] Salt-generation helper function
	Purpose: Generate a random salt in-script

	Usage: _UAF_GenerateSalt( [nWords] )

	Input:
		[nWords]: optional int specifying number of 32-bit words in output
			(when omitted, defaults to the globally defined $_UAF_DEF_SALT_NWORDS value)
	
	Return: [binary], PRNG binary salt
#ce
Func _UAF_GenerateSalt($nwords = $_UAF_DEF_SALT_NWORDS)

	Local $rand_bin_raw
	Local $salt = Binary("0x")

	; append 32-bit words to get desired size:
	For $i = 1 To $nwords
		$rand_bin_raw = Binary( Random() )
		; append just the random 32-bit component of the resulting float:
		$salt &= BinaryMid( $rand_bin_raw, 4, 4)
	Next

	Return $salt

EndFunc
