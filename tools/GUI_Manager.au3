#cs LICENSING AND PURPOSE
	vim: ts=4 sw=4 nu ai foldmethod=syntax

	Purpose: GUI Manager frontend to UserAuthFlat library

	Copyright Josh Cepek 2012

	Licensed under the GNU AGPL version 3

	See Licensing\agpl-3.0.txt for full licensing details.

#ce

Opt("MustDeclareVars", True)
Opt("GUIOnEventMode", 1)		; use On-Event GUI mode
#NoAutoIt3Execute

#include "..\UserAuthFlat.au3"

#include <Constants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <EditConstants.au3>
#include <ComboConstants.au3>
#include <ButtonConstants.au3>

; global constants:

Global Const $MAP_REF_USER		= 0
Global Const $MAP_REF_CONTROL	= 1
; global param definitions:
Global Const $DEF_FIELD_PW		= True		; requests handling for password fields
; globals for editGUI types:
Global Const $EDIT_TYPE_ADD		= 1
Global Const $EDIT_TYPE_CHANGE	= 2
; global text constants:
Global $TEXT_HASH_BEST			= "Best available (" & _UAF_LookupDisplayByFormat($_UAF_BEST_FORMAT) & ")"
Global $TEXT_ROUNDS_DEFAULT		= "Hash default"
Global $TEXT_ROUNDS_MANUAL		= "Manually provided"
Global $TEXT_EDIT_ADD			= "Add a new user"
Global $TEXT_EDIT_CHANGE		= "Change user password"
; global constants tracking state:
Global $ACTIVE_FILE				= ""
Global $ACTIVE_FILE_PATH		= ""
Global $UNSAVED_CHANGES			= False

; create the main GUI window:

Global $mainGUI
Global $MAP_users_controls[1][2] = [[0,0]]
mainGUI_create()	; sets $mainGUI in the process

; init context (so 'add user' works right away)
_UAF_InitAuthContext()

; then show it:
GUISetState(@SW_SHOW, $mainGUI)

; sit around, waiting for UI events:

While True
	Sleep(50)
WEnd

#Region editGUI

; editGUI_create
Func editGUI_create($edit_type, $user_text = "")

	Local $style, $exStyle, $text

	; hide the mainGUI:
	GUISetState(@SW_HIDE, $mainGUI)

	; set $primary_text based on type of edit being performed:

	Switch $edit_type
	Case $EDIT_TYPE_ADD
		$text = $TEXT_EDIT_ADD
	Case $EDIT_TYPE_CHANGE
		$text = $TEXT_EDIT_CHANGE
	EndSwitch

	; FIXME: we want to add in support to paint this where the mainGUI was
	; create GUI:

	Global $editGUI = GUICreate("UAF User Editor", 400, 400)

	Global $editGUI_LBL_Primary	= GUICtrlCreateLabel($text, 10, 20, default, 20)

	; username field:

	$style = $GUI_SS_DEFAULT_INPUT
	; user field is read-only when updating user info:
	If $edit_type = $EDIT_TYPE_CHANGE Then
		$style = BitOR($style, $ES_READONLY)
	EndIf

	Global $editGUI_LBL_User	= GUICtrlCreateLabel("Username:", 10, 70, default, 20)
	Global $editGUI_EDIT_User	= GUICtrlCreateInput($user_text, 100, 70, 75, 20, $style)

	; password fields:

	$style = BitOR($GUI_SS_DEFAULT_INPUT, $ES_PASSWORD)

	Global $editGUI_LBL_Pass	= GUICtrlCreateLabel("Password:", 10, 100, default, 20)
	Global $editGUI_EDIT_Pass	= GUICtrlCreateInput("", 100, 100, 120, 20, $style)

	Global $editGUI_LBL_Pass2	= GUICtrlCreateLabel("Confirm:", 10, 130, default, 20)
	Global $editGUI_EDIT_Pass2	= GUICtrlCreateInput("", 100, 130, 120, 20, $style)

	; save/cancel buttons:

	$style = $BS_DEFPUSHBUTTON
	Global $editGUI_BTN_Save	= GUICtrlCreateButton("Save User", 80, 170, 80, 30, $style)
	Global $editGUI_BTN_Cancel	= GUICtrlCreateButton("Cancel", 190, 170, 80, 30)

	; hash field:

	; this style makes the dropdowns un-editable by hand
	; both the CBS controls below use this
	$style = BitOR($WS_VSCROLL, $CBS_DROPDOWNLIST)

	; set a display option for the default 'best' hash
	Global $editGUI_LBL_Hash	= GUICtrlCreateLabel("Hash:", 10, 230, default, 20)
	Global $editGUI_CBS_Hash	= GUICtrlCreateCombo($TEXT_HASH_BEST, 60, 230, 160, 20, $style)
	; populate hash list:
	editGUI_getHashes()

	; rounds:

	Global $editGUI_LBL_Rounds	= GUICtrlCreateLabel("Rounds:", 10, 260, default, 20)
	Global $editGUI_CBS_Rounds	= GUICtrlCreateCombo($TEXT_ROUNDS_DEFAULT, 60, 260, 160, 20, $style)
		GUICtrlSetData(default, $TEXT_ROUNDS_MANUAL)

	$style = BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY)

	Global $editGUI_LBL_Count	= GUICtrlCreateLabel("Manual:", 250, 260, default, 20)
	Global $editGUI_EDIT_Count	= GUICtrlCreateInput("", 300, 260, 40, 20, $style)

	; event listeners

	GUISetOnEvent($GUI_EVENT_CLOSE, "editGUI_close", $editGUI)
	GUICtrlSetOnEvent($editGUI_BTN_Cancel, "editGUI_close")
	GUICtrlSetOnEvent($editGUI_CBS_Rounds, "editGUI_CBS_Rounds")
	GUICtrlSetOnEvent($editGUI_BTN_Save, "editGUI_BTN_Save")

	; show the editGUI:
	GUISetState(@SW_SHOW, $editGUI)

EndFunc

; editGUI_getHashes()
Func editGUI_getHashes()

	Local $hashlist = _UAF_EnumFormats()

	For $i = 1 To UBound($hashlist) - 1

		GUICtrlSetData($editGUI_CBS_Hash, _UAF_LookupDisplayByFormat($hashlist[$i]))

	Next

EndFunc

; editGUI_CBS_Rounds()
Func editGUI_CBS_Rounds()
	
	Local $state, $formatID
	Local $data = GUICtrlRead($editGUI_CBS_Rounds)
	
	;debug:
	;MsgBox(0, 'debug', $data)

	Switch $data
	Case $TEXT_ROUNDS_DEFAULT
		; mark read-only and blank any value:
		$state = BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY)
		GUICtrlSetData($editGUI_EDIT_Count, "")
	Case $TEXT_ROUNDS_MANUAL
		; enable for edit:
		$state = $GUI_SS_DEFAULT_INPUT

		; populate with default rounds for selected hash:
		$formatID = editGUI_GetSelectedFormat()
		GUICtrlSetData($editGUI_EDIT_Count, _UAF_LookupRoundsByFormat($formatID) )
	EndSwitch

	GUICtrlSetStyle($editGUI_EDIT_Count, $state)

EndFunc

; editGUI_BTN_Save
Func editGUI_BTN_Save()

	Local $msg, $reply, $style, $error, $edit_type
	Local $user, $pass1, $pass2, $rounds_choice, $formatID

	; pull user (text is verified as part of _UAF_StoreUser()
	$user = GUICtrlRead($editGUI_EDIT_User)

	; don't allow an existing user to be clobbered when adding (allow when changing)
	$edit_type = GUICtrlRead($editGUI_LBL_Primary)
	If $edit_type = $TEXT_EDIT_ADD AND _UAF_GetUserIndex($user) Then
		$msg = "A user with that name already exists." & @LF
		$msg &= "Choose a different username, or change the "
		$msg &= "password from the primary window."
		UI_subMsg("User already exists", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; verify password:
	$pass1 = GUICtrlRead($editGUI_EDIT_Pass)
	$pass2 = GUICtrlRead($editGUI_EDIT_Pass2)
	If $pass1 <> $pass2 Then
		$msg = "Passwords do not match; re-enter and try again."
		UI_subMsg("Password Mismatch", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; warn on blank password:
	If $pass1 = "" Then
		$msg = "WARNING! Your password is BLANK!" & @LF & @LF
		$msg &="Is this REALLY what you want?"
		$style = BitOR($MB_ICONEXCLAMATION, $MB_YESNO, $MB_DEFBUTTON2)
		$reply = UI_subMsg("WARNING: Blank Password!", $msg, $style)

		If $reply = $IDNO Then
			Return
		EndIf
	EndIf

	; pull hash and convert it to a formatID:
	$formatID = editGUI_GetSelectedFormat()

	; rounds defaults to 0; if manually defined, use supplied value:
	Local $rounds = 0
	$rounds_choice = GUICtrlRead($editGUI_CBS_Rounds)
	If $rounds_choice = $TEXT_ROUNDS_MANUAL Then
		$rounds = GUICtrlRead($editGUI_EDIT_Count)
		If StringLen($rounds) = 0 Then ; disallow empty manual rounds
			$msg = "Manual rounds requested but no count provided."
			UI_subMsg("Missing round count", $msg, $MB_ICONEXCLAMATION)
			Return
		EndIf
	EndIf

	; store user, and reload / return on success
	_UAF_StoreUser($user, $pass1, $formatID, $rounds)
	$error = @error
	If NOT $error Then ; on success, reload userlist and close down editGUI
		mainGUI_reload_users()
		editGUI_close()
		$UNSAVED_CHANGES = True
		Return
	EndIf

	; on errors, provide a reasonable error message:
	Switch $error
	Case $_UAF_ERR_CRYPTO
		$msg = "Unexpected crypto failure"
	Case $_UAF_ERR_ROUNDS
		$msg = "The supplied rounds is out of acceptable bounds." & @LF
		$msg &= "Valid range is a whole nummber from " & $_UAF_DEF_ROUNDS_MIN & " to "
		$msg &= $_UAF_DEF_ROUNDS_MAX & "."
	Case $_UAF_ERR_BADCHAR
		$msg = "Bad Character: username may not contain ':' characters"
	Case $_UAF_ERR_NOUSER
		$msg = "Username may not be blank"
	Case Else
		$msg = "Unsupported error calling _UAF_StoreUser() function, error code: " & $error
	EndSwitch

	UI_subMsg("Error Saving User", $msg, $MB_ICONHAND)
	Return

EndFunc

; editGUI_close()
Func editGUI_close()

	GUIDelete($editGUI)

	GUISetState(@SW_SHOW, $mainGUI)

EndFunc

; editGUI_GetSelectedFormat
Func editGUI_GetSelectedFormat()

	Local $hash_choice, $formatID

	$hash_choice = GUICtrlRead($editGUI_CBS_Hash)
	Switch $hash_choice
	Case $TEXT_HASH_BEST
		$formatID = $_UAF_BEST_FORMAT
	Case Else ; convert selection into FormatID
		$formatID = _UAF_LookupFormatByDisplay($hash_choice)
	EndSwitch

	Return $formatID

EndFunc

#EndRegion

#Region mainGUI FUNCTIONS

; mainGUI_create() - create the mainGUI window
Func mainGUI_create()

	Local $style, $exStyle
	
	Global $mainGUI = GUICreate("UAF User Manager", 400, 400)

	; load/save buttons
	; TOP=20
	; BOTTOM=50
	Global $mainGUI_BTN_Load	= GUICtrlCreateButton("Load Auth File", 10, 20, 150, 30)
	Global $mainGUI_BTN_Save	= GUICtrlCreateButton("Save To Disk", 210, 20, 150, 30)
	Global $mainGUI_BTN_Reset	= GUICtrlCreateButton("New (blank) List", 210, 60, 150, 30)

	; Userlist:
	; TOP=80	(counting label)

	Global $mainGUI_LBL_Users	= GUICtrlCreateLabel("Users:", 10, 80, default, 20)

	Global $mainGUI_LST_Users	= GUICtrlCreateList("", 10, 100, 140, 150)
	
	; user action buttons:
	; TOP=120
	; BUTTOM=230

	Global $mainGUI_BTN_Add 	= GUICtrlCreateButton("Add User", 260, 120, default, 20)
	Global $mainGUI_BTN_Remove	= GUICtrlCreateButton("Remove User", 260, 150, default, 20)
	Global $mainGUI_BTN_Verify	= GUICtrlCreateButton("Verify Password", 260, 180, default, 20)
	Global $mainGUI_BTN_Change	= GUICtrlCreateButton("Change Password", 260, 210, default, 20)
	Global $mainGUI_BTN_Rename	= GUICtrlCreateButton("Rename User", 260, 240, default, 20)

	;Global $mainGUI_BTN_Debug	= GUICtrlCreateButton("Debug Button", 260, 270, default, 20)

	; add event handlers:

	GUISetOnEvent($GUI_EVENT_CLOSE, "mainGUI_close", $mainGUI)

	; button events:
	GUICtrlSetOnEvent($mainGUI_BTN_Load,	"mainGUI_BTN_Load")
	GUICtrlSetOnEvent($mainGUI_BTN_Save,	"mainGUI_BTN_Save")
	GUICtrlSetOnEvent($mainGUI_BTN_Reset,	"mainGUI_BTN_Reset")
	GUICtrlSetOnEvent($mainGUI_BTN_Add,		"mainGUI_BTN_Add")
	GUICtrlSetOnEvent($mainGUI_BTN_Verify,	"mainGUI_BTN_Verify")
	GUICtrlSetOnEvent($mainGUI_BTN_Change,	"mainGUI_BTN_Change")
	GUICtrlSetOnEvent($mainGUI_BTN_Remove,	"mainGUI_BTN_Remove")
	GUICtrlSetOnEvent($mainGUI_BTN_Rename,	"mainGUI_BTN_Rename")

	;GUICtrlSetOnEvent($mainGUI_BTN_Debug, "mainGUI_BTN_Debug")

EndFunc

; mainGUI_BTN_Debug() - Debug function
Func mainGUI_BTN_Debug()
	
	Local $data, $control

	;$control = MapControlByUser("MD5")
	$data = GUICtrlRead($mainGUI_LST_Users)

	MsgBox(0, 'debug', "Data Read: " & $data)

EndFunc

; mainGUI_BTN_Add() - Pivot to a new editGUI
Func mainGUI_BTN_Add()

	Local $msg
	
	; with no context, warn and return:
	If NOT _UAF_VerifyAuthContext() Then
		$msg = "No auth file is loaded." & @LF
		$msg &= "Load or create a new (empty) state and try again."
		UI_subMsg("No Auth Loaded", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf
	
	; create the editGUI with an 'add' type
	editGUI_create($EDIT_TYPE_ADD)

EndFunc

; mainGUI_BTN_Verify() - Verify a selected user's password
Func mainGUI_BTN_Verify()

	Local $user, $password, $result, $error, $msg

	; get selected user, aborting if no selection:

	$user = GUICtrlRead($mainGUI_LST_Users)
	If $user = "" Then ; warn and return
		$msg = "You haven't selected a user to verify"
		UI_subMsg("Nothing Selected", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; get password via input:

	GUISetState(@SW_HIDE, $mainGUI) ; note that mainGUI_subMsg() implicitly restores this

	$msg = "Verify password for user: " & $user
	$password = UI_subInput("Verify Password", $msg, default, $DEF_FIELD_PW)

	If @error Then ; user canceled input
		GUISetState(@SW_SHOW, $mainGUI)
		Return
	EndIf

	; verify user/pass:

	$result = _UAF_ValidateUser($user, $password)
	$error = @error

	$password = ""

	; UI notification depending on validation return:

	If $result Then

		$msg = "Successfully validated password for user: " & $user
		UI_subMsg("Successfully Validated", $msg)
		Return

	EndIf

	; otherwise, warn based on failure mode:

	$msg = "Failed validation for user: " & $user & @LF

	Switch $error
	Case $_UAF_ERR_UNSUPPORTED		; unsupported hashing format
		$msg &= "Reason: unsupported or unavailable hash format for user"
	Case $_UAF_ERR_OK				; no error, ie: bad password supplied
		$msg &= "Reason: bad password"
	Case Else
		$msg &= "Unhandled error. Error code: " & $error
	EndSwitch

	UI_subMsg("Failed Validation", $msg, $MB_ICONHAND)
		

EndFunc

; mainGUI_BTN_Rename() - Rename a user
Func mainGUI_BTN_Rename()

	Local $user, $newuser, $msg, $error

	; hide mainGUI
	GUISetState(@SW_HIDE, $mainGUI) ; implicitly restored only by UI_subMsg()

	; get selected user:
	$user = GUICtrlRead($mainGUI_LST_Users)
	If $user = "" Then ; warn and return
		$msg = "You haven't selected a user to rename"
		UI_subMsg("Nothing Selected", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; get username via input:
	$msg = "Rename user '" & $user & "' to:"
	$newuser = UI_subInput("Rename user", $msg, $user)
	If @error Then
		GUISetState(@SW_SHOW, $mainGUI)
		Return
	EndIf

	; try to rename:
	_UAF_RenameUser($user, $newuser)
	$error = @error
	If NOT $error Then
		mainGUI_reload_users()
		$UNSAVED_CHANGES = True
		GUISetState(@SW_SHOW, $mainGUI)
		Return
	EndIf

	; on error, report the reason:
	Switch $error
	Case $_UAF_ERR_NOUSER
		$msg = "The new username may not be blank."
	Case $_UAF_ERR_BADCHAR
		$msg = "The new username may not contain any ':' symbols"
	Case Else
		$msg = "Unhandled error when calling _UAF_RenameUser(). Error code: " & $error
	EndSwitch
	
	UI_subMsg("Error renaming user", $msg, $MB_ICONHAND)

	Return

EndFunc

; mainGUI_BTN_Change() - Change a selected user's password
Func mainGUI_BTN_Change()

	Local $msg, $user

	$user = GUICtrlRead($mainGUI_LST_Users)

	; user must be selected:
	If StringLen($user) = 0 Then
		$msg = "You must select a user in order to change a password."
		UI_subMsg("No user selected", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; create editGUI with the user:
	editGUI_create($EDIT_TYPE_CHANGE, $user)

EndFunc

; mainGUI_BTN_Remove() - remove a selected user
Func mainGUI_BTN_Remove()

	Local $msg, $user, $error, $response, $state

	$user = GUICtrlRead($mainGUI_LST_Users)

	; user must be selected:
	If StringLen($user) = 0 Then
		$msg = "You must select a user before removing one."
		UI_subMsg("No user selected", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; verify user intent:
	$msg = "Are you sure you want to remove user '" & $user & "' ?"
	$state = BitOR($MB_YESNO, $MB_DEFBUTTON2, $MB_ICONQUESTION)
	$response = UI_subMsg("Confirm remove user", $msg, $state)
	If $response = $IDNO Then
		Return
	EndIf

	; remove user, and reload users on success
	_UAF_RemoveUser($user)
	$error = @error
	If NOT $error Then
		mainGUI_reload_users()
		$UNSAVED_CHANGES = True
		Return
	EndIf

	; report any error - one shouldn't really occur, but we do so anyway:
	$msg = "An unhandled error occurred when calling _UAF_RemoveUser()" & @LF
	$msg &= "Error code: " & $error
	UI_subMsg("Error removing user", $msg, $MB_ICONHAND)
	Return

EndFunc

; mainGUI_BTN_Load() - prompt for and load an auth file from disk
Func mainGUI_BTN_Load()
	
	Local $user_file, $opts, $msg, $filemask, $response, $state

	; if unsaved changes, warn/confirm:
	If $UNSAVED_CHANGES Then
		$msg = "You have made changes without saving your file." & @LF
		$msg &= "Do you want to continue loading and drop these changes?"
		$state = BitOR($MB_ICONEXCLAMATION, $MB_YESNO, $MB_DEFBUTTON2)
		$response = UI_subMsg("Unsaved changes", $msg, $state)
		If $response = $IDNO Then
			Return
		EndIf
	EndIf

	; prompt user to select the auth file

	$opts = $FD_FILEMUSTEXIST
	$filemask = "UAF Auth Files(*.auth)|Text Files (*.txt)|All Files (*.*)"
	$user_file = FileOpenDialog("Select UAF Auth File", "", $filemask, $opts, "", $mainGUI)

	If @error Then
		Return
	EndIf

	; try to load the file into active UAF state:
	_UAF_LoadAuthFile($user_file)

	If @error Then

		$msg = "Failed to load the auth file"
		UI_subMsg($MB_ICONHAND, "Error loading file", $msg)

	EndIf

	; call mainGUI_reload_users to refresh the users display list
	mainGUI_reload_users()

	; save the loaded file into state globals:
	UI_updateActive($user_file)

EndFunc

; mainGUI_BTN_Save() - prompt to save the state back to disk
Func mainGUI_BTN_Save()

	Local $msg, $count, $user_file, $filter, $opts, $error, $extended

	; check context:
	If NOT _UAF_VerifyAuthContext() OR _
	UBound(_UAF_EnumUsers()) = 1 Then
		$msg = "Nothing available to save." & @LF
		$msg &= "Load a file first, or create an new (empty) state and add users."
		UI_subMsg("Nothing to save", $msg, $MB_ICONEXCLAMATION)
		Return
	EndIf

	; save dialog:
	$filter = "UAF Auth Files(*.auth)|Text Files (*.txt)|All Files (*.*)"
	$opts = $FD_PROMPTOVERWRITE
	$user_file = FileSaveDialog("Save UAF File", $ACTIVE_FILE_PATH, $filter, $opts, $ACTIVE_FILE, $mainGUI)

	If @error Then
		Return
	EndIf

	; try to save it; on success, update user list, unsaved status, and return
	_UAF_SaveAuthFile($user_file)
	$error = @error
	$extended = @extended
	If NOT $error Then
		; save file info to global state:
		UI_updateActive($user_file)
		$UNSAVED_CHANGES = False
		Return
	EndIf

	Switch $error
	Case $_UAF_ERR_FILEWRITE ; file opened, but some entries failed to write (!)
		$msg = "File opened, but " & $extended & " lines failed to be written." & @LF & @LF
		$msg &= "It's possible the disk is full, encountered an error, or an "
		$msg &= "unexpected failure occurred."
	Case $_UAF_ERR_FILEOPEN ; file open error
		$msg = "Failed to open the file for writing. Check permissions and try again."
	Case Else
		$msg = "Unexpected error occurred calling _UAF_SaveAuthFile(). Error code: " & $error
	EndSwitch

	UI_subMsg("Error saving file", $msg, $MB_ICONHAND)
	Return

EndFunc

; mainGUI_BTN_Reset() - reset loaded users
Func mainGUI_BTN_Reset()

	Local $msg, $response, $state

	; warn on unsaved changes
	If $UNSAVED_CHANGES Then
		$msg = "You have made changes without saving your file." & @LF
		$msg &= "Do you want to start a blank list and drop these changes?"
		$state = BitOR($MB_ICONEXCLAMATION, $MB_YESNO, $MB_DEFBUTTON2)
		$response = UI_subMsg("Unsaved changes", $msg, $state)
		If $response = $IDNO Then
			Return
		EndIf
	EndIf

	; init context
	_UAF_InitAuthContext()
	mainGUI_reload_users()

	; reset active file paths and change state:
	$ACTIVE_FILE = ""
	$ACTIVE_FILE_PATH = ""
	$UNSAVED_CHANGES = ""

EndFunc

; mainGUI_reload_users() - reload the user list based on UAF state
Func mainGUI_reload_users()

	Local $userlist
	
	; check for UAF context:

	If NOT _UAF_VerifyAuthContext() Then
		Return False
	EndIf
	
	; enumerate users:

	$userlist = _UAF_EnumUsers()
	If @error Then
		Return False
	EndIf

	; clear and re-populate $mainGUI_LST_Users:

	GUICtrlSetData($mainGUI_LST_users, "")

	For $i = 1 To UBound($userlist) - 1
	
		GUICtrlSetData($mainGUI_LST_users, $userlist[$i])

	Next

EndFunc

; mainGUI_close() - close event handler
Func mainGUI_close()

	Local $msg, $state, $response
	
	; confirm before exiting with unsaved changes:
	If $UNSAVED_CHANGES Then
		$msg = "You have made changes without saving your file." & @LF
		$msg &= "Do you want to exit and drop these changes?"
		$state = BitOR($MB_ICONEXCLAMATION, $MB_YESNO, $MB_DEFBUTTON2)
		$response = UI_subMsg("Unsaved changes", $msg, $state)
		If $response = $IDNO Then
			Return
		EndIf
	EndIf

	Exit

EndFunc

#EndRegion mainGUI FUNCTIONS

#Region shared display functions

; UI_subMsg() - display a message box while hiding the last used GUI
Func UI_subMsg($title, $text, $style = $MB_OK, $timeout = 0)

	Local $response

	GUISetState(@SW_HIDE)

	$response = MsgBox($style, $title, $text, $timeout)

	GuiSetState(@SW_SHOW)

	Return $response

EndFunc

; UI_subInput() - display an input box
Func UI_subInput($title, $prompt, $default = "", $isPassword = False)

	Local $response, $pw = ""

	If $isPassword Then
		$pw = "*"
	EndIf

	$response = InputBox($title, $prompt, $default, $pw)

	Return SetError(@error, 0, $response)

EndFunc

; UI_updateActive() - updates active file for tracking
Func UI_updateActive($filename)

	Local $splitpoint = StringInStr($filename, "\", $STR_NOCASESENSE, -1)
	$ACTIVE_FILE_PATH = StringMid($filename, 1, $splitpoint)
	$ACTIVE_FILE = StringMid($filename, $splitpoint + 1)

EndFunc

#EndRegion shared display functions

#Region MAP_users_controls

Func Map_Users_Controls_Reset()

	Local $control

	For $i = 1 To UBound($MAP_users_controls) - 1
		
		$control = $MAP_users_controls[$i][$MAP_REF_CONTROL]
		GUICtrlDelete($control)

	Next

	; reset array:
	Global $MAP_users_controls[1][2] = [[0,0]]

EndFunc

Func Map_Users_Controls_Add($user)

	; add control
	
	;MsgBox(0, 'debug', "Adding user listviewitem: " & $user)

	Local $control = GUICtrlCreateListViewItem($user, $mainGUI_LST_Users)

	; extend MAP array and add paring

	Local $dims = UBound($MAP_users_controls)
	ReDim $MAP_users_controls[$dims + 1][2]

	$MAP_users_controls[$dims][$MAP_REF_USER] = $user
	$MAP_users_controls[$dims][$MAP_REF_CONTROL] = $control

EndFunc

Func Map_Users_Controls_Remove($user)
	
	Local $control, $ref

	; identify control/ref from user:

	$control = MapControlByUser($user)
	$ref = @extended

	If @error Then
		Return False
	EndIf
	
	; remove control:

	GUICtrlDelete($control)

	; remove the entry from the MAP array:

	Local $dims = UBound($MAP_users_controls)

	For $i = $ref + 1 To $dims - 1
		
		; move element up one:

		$user = $MAP_users_controls[$i][$MAP_REF_USER]
		$control = $MAP_users_controls[$i][$MAP_REF_CONTROL]

		$MAP_users_controls[$i - 1][$MAP_REF_USER] = $user
		$MAP_users_controls[$i - 1][$MAP_REF_CONTROL] = $control

	Next

	; trim the array:

	ReDim $MAP_users_controls[$dims - 1][2]

EndFunc

Func MapUserByControl($id)
	Local $v = Map_Lookup($id, $MAP_REF_CONTROL, $MAP_REF_USER)
	Return SetError(@error, @extended, $v)
EndFunc
; cont'd
Func MapControlByUser($id)
	Local $v = Map_Lookup($id, $MAP_REF_USER, $MAP_REF_CONTROL)
	Return SetError(@error, @extended, $v)
EndFunc

; Map* helper:
Func Map_Lookup($id, $src, $dst)

	Local $value, $check
	
	; cycle through array for a match:

	For $i = 1 To UBound($MAP_users_controls) - 1
		
		$check = $MAP_users_controls[$i][$src] 
		$value = $MAP_users_controls[$i][$dst] 
		If $id = $check Then
			Return SetExtended($i, $value)
		EndIf

	Next

	; no match:

	Return SetError(1, 0, "")
	
EndFunc


#EndRegion MAP_users_controls
